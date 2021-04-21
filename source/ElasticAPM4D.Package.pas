unit ElasticAPM4D.Package;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  SyncObjs,
  ElasticAPM4D.Transaction,
  ElasticAPM4D.Metadata,
  ElasticAPM4D.User,
  ElasticAPM4D.Span,
  ElasticAPM4D.Error,
  Winapi.Windows,
  System.Math,
  Rest.Client,
  Rest.Types,
  System.DateUtils,
  Rest.HttpClient;

type
  TPackage = class
  private
    FMetadata: TMetadata;
    FTransaction: TTransaction;
    FSpanList: TObjectList<TSpan>;
    FErrorList: TObjectList<TError>;
    FOpenSpanStack: TList;
    FUser: TUser;
    FHeader: string;
    function ExtractTraceId: string;
    function ExtractParentID: string;
    function GetHeader: string;
    procedure SetHeader(const Value: string);
  public
    constructor Create;
    destructor Destroy; override;

    function GetAsNdJson(): string;

    function SpanIsOpen: Boolean;
    function CurrentSpan: TSpan;

    property Metadata: TMetadata read FMetadata write FMetadata;
    property Transaction: TTransaction read FTransaction write FTransaction;
    property SpanList: TObjectList<TSpan> read FSpanList write FSpanList;
    property ErrorList: TObjectList<TError> read FErrorList write FErrorList;
    property OpenSpanStack: TList read FOpenSpanStack write FOpenSpanStack;
    property User: TUser read FUser write FUser;
    property Header: string read GetHeader write SetHeader;

  end;

  TSender = class(TThread)
  private
    class var FSender: TSender;

  const
    C_MetricInterval      = 5 * 60 * 1000; // 5min
    C_ConfigFetchInterval = 60 * 1000;     // 1min
  private
    FEvent:        TEvent;
    FPackageQueue: TThreadList<TPackage>;
    FSendQueue:    TThreadList<TPair<string, string>>;
  private
    FLastFetch, FLastMetric: TDateTime;
    FRestHttp:               TRESTHTTP;
    FRestClient:             TRestClient;
    FAgentRequest:           TRestRequest;

    function SendToElasticAPM(const AUrl, AHeader, AJson: string): Boolean;
  protected
    procedure Execute(); override;
    procedure ProcessPackageList();
    procedure ProcessMetrics();
    procedure ProcessSendList();
    procedure ProcessConfigFetch();

    procedure TerminatedSet; override;
  public
    procedure AfterConstruction(); override;
    destructor Destroy; override;

    procedure AddPackageToQueue(const aPackage: TPackage);
    procedure AddToSendQueue(const AHeader, aData: string);
  public
    class function Instance(): TSender;
    class procedure TerminateAndFree();
  end;

implementation

uses
  ElasticAPM4D.ndJson,
  ElasticAPM4D.Utils,
  ElasticAPM4D.Resources,
  ElasticAPM4D;

{ TPackage }

constructor TPackage.Create;
begin
  FMetadata := TMetadata.Create;
  FTransaction := TTransaction.Create;
  FSpanList := TObjectList<TSpan>.Create;
  FOpenSpanStack := TList.Create;
  FErrorList := TObjectList<TError>.Create;
  FUser := TUser.Create;
  FHeader := '';
end;

function TPackage.CurrentSpan: TSpan;
begin
  if not SpanIsOpen then
    Exit(nil);

  Result := FOpenSpanStack.Items[Pred(FOpenSpanStack.Count)];
end;

destructor TPackage.Destroy;
begin
  FTransaction.Free;
  FMetadata.Free;
  FreeAndNil(FSpanList);
  FreeAndNil(FErrorList);
  FOpenSpanStack.Free;
  FUser.Free;
  inherited;
end;

function TPackage.SpanIsOpen: Boolean;
begin
  Result := FOpenSpanStack.Count > 0;
end;

function TPackage.GetHeader: string;
begin
  Result := FHeader;
  if Result.IsEmpty then
  begin
    if SpanIsOpen then
      Result := Format(sHEADER, [FTransaction.trace_id, CurrentSpan.id])
    else
      Result := Format(sHEADER, [FTransaction.trace_id, FTransaction.id]);
  end
end;

function TPackage.GetAsNdJson: string;
var
  ndJson: TndJson;
begin
  ndJson := TndJson.Create;
  try
    ndJson.Add(FMetadata);
    ndJson.Add(FTransaction);
    ndJson.Add(FSpanList);
    ndJson.Add(FErrorList);

    Result := ndJson.Get;
  finally
    ndJson.Free;
  end;
end;

function TPackage.ExtractParentID: string;
begin
  Result := Copy(FHeader, 37, 16);
end;

function TPackage.ExtractTraceId: string;
begin
  Result := Copy(FHeader, 4, 32);
end;

procedure TPackage.SetHeader(const Value: string);
begin
  FHeader := Value;
  if not FHeader.IsEmpty then
  begin
    FTransaction.trace_id  := ExtractTraceId;
    FTransaction.parent_id := ExtractParentID;
  end;
end;

{ TSender }

class function TSender.Instance: TSender;
begin
  if FSender <> nil then
    Exit(FSender);

  GlobalNameSpace.BeginWrite;
  try
    if FSender <> nil then // created in the mean time?
      Exit(FSender);

    FSender := TSender.Create(False);
    Result  := FSender;
  finally
    GlobalNameSpace.EndWrite;
  end;
end;

class procedure TSender.TerminateAndFree;
begin
  if FSender = nil then
    Exit;

  FSender.Terminate();
  FSender.WaitFor();
  FSender.Free;
end;

procedure TSender.AfterConstruction;
begin
  inherited;
  FEvent        := TEvent.Create();
  FPackageQueue := TThreadList<TPackage>.Create();
  FSendQueue    := TThreadList < TPair < string, string >>.Create();

  FLastFetch  := Now();
  FLastMetric := Now();
end;

destructor TSender.Destroy;
begin
  FEvent.Free;
  FPackageQueue.Free;
  FSendQueue.Free;
  inherited;
end;

procedure TSender.TerminatedSet;
begin
  FEvent.SetEvent();
  inherited TerminatedSet();
end;

procedure TSender.AddPackageToQueue(const aPackage: TPackage);
begin
  FPackageQueue.Add(aPackage);
  FEvent.SetEvent();
end;

procedure TSender.AddToSendQueue(const AHeader, aData: string);
begin
  FSendQueue.Add(TPair<string, string>.Create(AHeader, aData));
  FEvent.SetEvent();
end;

procedure TSender.Execute;
var
  duration: Integer;
begin
  TThread.NameThreadForDebugging(Self.UnitName + '.' + Self.ClassName);

  // event's cannot be sent using TRestClient, using low level TRestHttp instead
  FRestHttp                     := TRESTHTTP.Create();
  FRestHttp.Request.ContentType := 'application/x-ndjson';

  FRestClient          := TRestClient.Create(TConfig.GetUrlElasticAPM());
  FAgentRequest        := TRestRequest.Create(FRestClient);
  FAgentRequest.Method := TRESTRequestMethod.rmGET;
  // https://www.elastic.co/guide/en/apm/server/current/agent-configuration-api.html
  FAgentRequest.Resource := '/config/v1/agents';
  FAgentRequest.AddParameter('service.name', TConfig.GetAppName, TRESTRequestParameterKind.pkQUERY);

  while not Terminated do
  begin
    duration := MinIntValue([C_MetricInterval - MilliSecondsBetween(Now(), FLastMetric), // metrics
      C_ConfigFetchInterval - MilliSecondsBetween(Now(), FLastFetch), // config
      30 * 1000]); // default 30s
    if duration > 0 then
      FEvent.WaitFor(duration);
    FEvent.ResetEvent();

    if Terminated then
      Break;

    ProcessConfigFetch();
    ProcessPackageList();
    ProcessSendList();
  end;
end;

function TSender.SendToElasticAPM(const AUrl, AHeader, AJson: string): Boolean;
var
  DataSend, Stream: TStringStream;
begin
  Result := False;

  DataSend := TStringStream.Create(AJson, TEncoding.UTF8);
  Stream   := TStringStream.Create('');
  try
{$MESSAGE warn 'TODO: "Authorization", "ApiKey " + apikey'}
    // TODO: "Authorization", "Bearer " + secretToken
    try
      FRestHttp.Request.CustomHeaders.Clear();
      FRestHttp.Request.CustomHeaders.Values[sHEADER_KEY] := AHeader;
      FRestHttp.Post(AUrl, DataSend, Stream);

      Result := True;
    except
      on e: EIdHTTPProtocolException do
        OutputDebugString(pchar(e.ClassName + ': ' + e.ErrorCode.ToString + ': ' + e.ErrorMessage));
      on e: Exception do
        OutputDebugString(pchar(e.ClassName + ': ' + e.Message));
    end;
  finally
    DataSend.Free;
    Stream.Free;
  end;
end;

procedure TSender.ProcessConfigFetch;
var
  Value:          string;
  FormatSettings: TFormatSettings;
begin
  if MilliSecondsBetween(Now(), FLastFetch) < C_ConfigFetchInterval then
    Exit;
  FLastFetch := Now();

  // http://127.0.0.1:8200/config/v1/agents?service.name=test-service
  FAgentRequest.Execute;

  Value := 'true'; // default
  FAgentRequest.Response.GetSimpleValue('recording', Value);
  TElasticAPM4D.IsRecording := (Value = 'true');

  Value := 'off'; // default
  FAgentRequest.Response.GetSimpleValue('capture_body', Value);
  TElasticAPM4D.IsCaptureBody := (Value <> 'off'); // off, all, errors, transactions

  Value := 'false'; // default
  FAgentRequest.Response.GetSimpleValue('capture_headers', Value);
  TElasticAPM4D.IsCaptureHeaders := (Value = 'true');

  FormatSettings.DecimalSeparator := '.';
  Value                           := '1.0'; // default
  FAgentRequest.Response.GetSimpleValue('transaction_sample_rate', Value);
  TElasticAPM4D.TransactionSampleRate := Single.Parse(Value, FormatSettings);

  { possible agent config's:
    - transaction_max_spans: "500",
    - span_frames_min_duration: 5ms/s/m
  }
end;

procedure TSender.ProcessPackageList();
var
  packages: TArray<TPackage>;
  Package:  TPackage;
begin
  with FPackageQueue.LockList() do
    try
      if Count <= 0 then
        Exit;

      packages := ToArray();
      Clear();
    finally
      FPackageQueue.UnlockList();
end;

  for Package in packages do
begin
    if TConfig.GetIsActive then
      TSender.Instance.AddToSendQueue(Package.GetHeader(), Package.GetAsNdJson());
    // SendToElasticAPM(TConfig.GetUrlElasticAPMEvents, GetHeader, ndJson.Get);
    // Package.ToSend();
    Package.Free;
  end;
end;

procedure TSender.ProcessSendList;
var
  data: TArray<TPair<string, string>>;
  item: TPair<string, string>;
  begin
  with FSendQueue.LockList() do
    try
      if Count <= 0 then
        Exit;

      data := ToArray();
      Clear();
    finally
      FSendQueue.UnlockList();
  end;

  for item in data do
    if TConfig.GetIsActive then
      SendToElasticAPM(TConfig.GetUrlElasticAPMEvents(), item.Key, item.Value);
end;

end.

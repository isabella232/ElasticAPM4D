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
  ElasticAPM4D.MetricSet,
  ElasticAPM4D.MetricSet.Defaults,
  Winapi.Windows,
  System.Math,
  Rest.Client,
  Rest.Types,
  System.DateUtils,
  Rest.HttpClient,
  System.IOUtils;

type
  TPackage = class
  private
    class var FMetadata: TMetadata;
  private
    FTransaction:   TTransaction;
    FSpanList:      TObjectList<TSpan>;
    FErrorList:     TObjectList<TError>;
    FOpenSpanStack: TList;
    FUser:          TUser;
    FHeader:        string;
    function ExtractTraceId: string;
    function ExtractParentID: string;
    function GetHeader: string;
    procedure SetHeader(const Value: string);
    function GetSpanList: TObjectList<TSpan>;
    function GetOpenSpanStack: TList;
    function GetErrorList: TObjectList<TError>;
  public
    class constructor Create;
    class destructor Destroy;

    constructor Create;
    destructor Destroy; override;

    function GetAsNdJson(): string;

    function SpanIsOpen: Boolean;
    function CurrentSpan: TSpan;

    class property Metadata: TMetadata read FMetadata;
    property Transaction: TTransaction read FTransaction write FTransaction;
    property SpanList: TObjectList<TSpan> read GetSpanList write FSpanList;
    property ErrorList: TObjectList<TError> read GetErrorList write FErrorList;
    property OpenSpanStack: TList read GetOpenSpanStack write FOpenSpanStack;
    property User: TUser read FUser write FUser;
    property Header: string read GetHeader write SetHeader;

    class function GetMetricsAsNdJson(): string;
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

    FConnected:    Boolean;
    FNotSendCount: Integer;

    function SendToElasticAPM(const AUrl, AJson: string): Boolean;
  protected
    procedure Execute(); override;
    procedure ProcessPackageList();
    procedure ProcessMetrics();
    procedure ProcessSendList();
    procedure ProcessConfigFetch();
    procedure ProcessFiles();

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
  WinInet,
  ElasticAPM4D.ndJson,
  ElasticAPM4D.Utils,
  ElasticAPM4D.Resources,
  ElasticAPM4D;

function CheckUrl(const url: string): Boolean;
var
  hSession, hfile: hInternet;
begin
  Result   := False;
  hSession := InternetOpen('InetURL:/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hSession <> nil then
  begin
    hfile := InternetOpenUrl(hSession, pchar(url), nil, 0, INTERNET_FLAG_RELOAD, 0);
    if hfile <> nil then
    begin
      Result := True;
      InternetCloseHandle(hfile);
    end;
    InternetCloseHandle(hSession);
  end;
end;

{ TPackage }

constructor TPackage.Create;
begin
  // create minimal objects
  FTransaction := TTransaction.Create;
  FHeader      := '';
end;

class constructor TPackage.Create;
begin
  FMetadata := TMetadata.Create; // this one is slow, so init only once!
end;

function TPackage.CurrentSpan: TSpan;
begin
  if not SpanIsOpen then
    Exit(nil);

  Result := OpenSpanStack.Items[Pred(FOpenSpanStack.Count)];
end;

class destructor TPackage.Destroy;
begin
  FMetadata.Free;
end;

destructor TPackage.Destroy;
begin
  FTransaction.Free;
  FreeAndNil(FSpanList);
  FreeAndNil(FErrorList);
  FOpenSpanStack.Free;
  FUser.Free;
  inherited;
end;

function TPackage.SpanIsOpen: Boolean;
begin
  Result := (FOpenSpanStack <> nil) and (FOpenSpanStack.Count > 0);
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
    FMetadata.Service.Environment := TConfig.Environment;
    ndJson.Add(FMetadata);
    ndJson.Add(FTransaction);
    ndJson.Add(FSpanList);
    ndJson.Add(FErrorList);

    Result := ndJson.Get;
  finally
    ndJson.Free;
  end;
end;

function TPackage.GetErrorList: TObjectList<TError>;
begin
  if FErrorList = nil then
    FErrorList := TObjectList<TError>.Create();
  Result       := FErrorList;
end;

function TPackage.GetOpenSpanStack: TList;
begin
  if FOpenSpanStack = nil then
    FOpenSpanStack := TList.Create;
  Result           := FOpenSpanStack;
end;

function TPackage.GetSpanList: TObjectList<TSpan>;
begin
  if FSpanList = nil then
    FSpanList := TObjectList<TSpan>.Create;
  Result      := FSpanList;
end;

function TPackage.ExtractParentID: string;
begin
  Result := Copy(FHeader, 37, 16);
end;

function TPackage.ExtractTraceId: string;
begin
  Result := Copy(FHeader, 4, 32);
end;

class function TPackage.GetMetricsAsNdJson(): string;
var
  ndJson: TndJson;
begin
  if not TConfig.GetIsActive then
    Exit;
  ndJson := TndJson.Create;
  try
    ndJson.Add(FMetadata);

    var
    FMetricList := TObjectList<TBaseMetricSet>.Create();
    var
    metric := TMetricSet<TBaseMetric>.Create();
    FMetricList.Add(metric);
    ndJson.Add(FMetricList);

    Result := ndJson.Get();
  finally
    ndJson.Free;
  end;
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

  if TDirectory.Exists(ExtractFilePath(ParamStr(0)) + 'apm\') and (TDirectory.GetFiles(ExtractFilePath(ParamStr(0)) + 'apm\', '*.ndjson') <> nil) then
    FNotSendCount := 1;

  // event's cannot be sent using TRestClient, using low level TRestHttp instead
  FRestHttp                     := TRESTHTTP.Create();
  FRestHttp.Request.ContentType := 'application/x-ndjson';

  FRestClient          := TRestClient.Create(TConfig.GetUrlElasticAPM());
  FAgentRequest        := TRestRequest.Create(FRestClient);
  FAgentRequest.Method := TRESTRequestMethod.rmGET;
  // https://www.elastic.co/guide/en/apm/server/current/agent-configuration-api.html
  FAgentRequest.Resource := '/config/v1/agents';
  FAgentRequest.AddParameter('service.name', TConfig.GetAppName, TRESTRequestParameterKind.pkQUERY);

  FConnected := CheckUrl(FAgentRequest.Client.BaseURL);

  while not Terminated do
  begin
    ProcessConfigFetch();
    ProcessPackageList();
    ProcessMetrics();
    ProcessSendList();

    duration := MinIntValue([C_MetricInterval - MilliSecondsBetween(Now(), FLastMetric), // metrics
      C_ConfigFetchInterval - MilliSecondsBetween(Now(), FLastFetch), // config
      30 * 1000]); // default 30s
    if duration > 0 then
      FEvent.WaitFor(duration);
    FEvent.ResetEvent();

    if Terminated then
      Break;
  end;
end;

function TSender.SendToElasticAPM(const AUrl, AJson: string): Boolean;
var
  DataSend, Stream: TStringStream;
  dir:              string;

  procedure _StoreAsFile(const AJson: string);
  begin
    dir := ExtractFilePath(ParamStr(0)) + 'apm\';
    ForceDirectories(dir);
    TFile.WriteAllText(dir + 'apm_' + FormatDateTime('yyyy-mm-dd_hh-nn-ss.zzz', Now) + '.ndjson', AJson, TEncoding.UTF8);
    Inc(FNotSendCount);
  end;

begin
  Result := False;

  if not FConnected then
  begin
    _StoreAsFile(AJson);
    Exit;
  end;

  DataSend := TStringStream.Create(AJson, TEncoding.UTF8);
  Stream   := TStringStream.Create('');
  try
{$MESSAGE warn 'TODO: "Authorization", "ApiKey " + apikey'}
    // TODO: "Authorization", "Bearer " + secretToken
    try
      FRestHttp.Post(AUrl, DataSend, Stream);
      Result := True;
    except
      on e: Exception do
      begin
        FConnected := False;
        OutputDebugString(pchar('Failed to store events to: ' + AUrl + ', error = ' + e.ClassName + ': ' + e.Message));
        _StoreAsFile(AJson);
      end;
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

  if not FConnected then
    FConnected := CheckUrl(FAgentRequest.Client.BaseURL);
  if not FConnected then
    Exit;

  // http://127.0.0.1:8200/config/v1/agents?service.name=test-service
  try
    FAgentRequest.Execute;
  except
    on e: Exception do
    begin
      FConnected := False;
      OutputDebugString(pchar('Failed to fetch config from: ' + FAgentRequest.Client.BaseURL + '/' + FAgentRequest.FullResource + ', error = ' + e.ClassName + ': ' +
        e.Message));
      Exit;
    end;
  end;

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

procedure TSender.ProcessMetrics;
begin
  if MilliSecondsBetween(Now(), FLastMetric) < C_MetricInterval then
    Exit;
  FLastMetric := Now();

  TSender.Instance.AddToSendQueue('', TPackage.GetMetricsAsNdJson());
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
    Package.Free;
  end;
end;

procedure TSender.ProcessSendList;
var
  data: TArray<TPair<string, string>>;
  item: TPair<string, string>;
  isSend: Boolean;
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

  isSend := False;
  for item in data do
    if TConfig.GetIsActive then
      isSend := SendToElasticAPM(TConfig.GetUrlElasticAPMEvents(), item.Value);

  if isSend and (FNotSendCount > 0) then
    ProcessFiles();
end;

procedure TSender.ProcessFiles;
var
  files:   TArray<string>;
  f, data: string;
begin
  files := TDirectory.GetFiles(ExtractFilePath(ParamStr(0)) + 'apm\', '*.ndjson');
  for f in files do
  begin
    data := TFile.ReadAllText(f);
    TFile.Delete(f);
    if not SendToElasticAPM(TConfig.GetUrlElasticAPMEvents(), data) then
      Exit;
  end;

  FNotSendCount := 0;
end;

end.

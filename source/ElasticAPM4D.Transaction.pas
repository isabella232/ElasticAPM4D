unit ElasticAPM4D.Transaction;

interface

uses
  System.Classes, System.SysUtils, ElasticAPM4D.Context;

type
  TSpanCount = class
  private
    FDropped: Integer;
    FStarted: Integer;
  public
    constructor Create;

    procedure Inc;
    procedure Dec;
    procedure Reset;

    property Dropped: Integer read FDropped;
    property Started: Integer read FStarted;
  end;

  // https://github.com/elastic/apm-server/blob/v7.12.0/docs/spec/v2/transaction.json
  TTransaction = class
  private
    FStartDate: TDateTime;
    Fid: string;
    Ftrace_id: string;
    Fname: string;
    Ftype: string;
    Fresult: string;
    Fduration: int64;
    Fcontext: TContext;
    Fspan_count: TSpanCount;
    Fsampled: boolean;
    Fparent_id: string;
    Ftimestamp: int64;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start(const AType, AName: string);
    procedure &End;

    function ToJsonString: string;

    property Id: string read Fid;
    property Trace_id: string read Ftrace_id write Ftrace_id;
    property Parent_id: string read Fparent_id write Fparent_id;
    property Name: string read Fname write Fname;
    property &type: string read Ftype;
    property Span_count: TSpanCount read Fspan_count;
    property Context: TContext read Fcontext write Fcontext;
    property Duration: int64 read Fduration write Fduration;
    property &result: string read Fresult write Fresult;
    property Sampled: boolean read Fsampled write Fsampled;
    property Timestamp: int64 read Ftimestamp write Ftimestamp;
  end;

implementation

Uses
  System.DateUtils, REST.Json, ElasticAPM4D.Utils, ElasticAPM4D.Resources;

{ TSpanCount }

constructor TSpanCount.Create;
begin
  Reset;
end;

procedure TSpanCount.Dec;
begin
  FDropped := FDropped - 1;
end;

procedure TSpanCount.Inc;
begin
  FStarted := FStarted + 1;
  FDropped := FDropped + 1;
end;

procedure TSpanCount.Reset;
begin
  FDropped := 0;
  FStarted := 0;
end;

{ TTransaction }

constructor TTransaction.Create;
begin
  Fspan_count := TSpanCount.Create;
  Fid := TUUid.Get64b;
  Ftrace_id := TUUid.Get128b;
  Fsampled := true;
end;

destructor TTransaction.Destroy;
begin
  if Assigned(Fcontext) then
    Fcontext.Free;
  Fspan_count.Free;
  inherited;
end;

procedure TTransaction.&End;
begin
  Fduration := MilliSecondsBetween(now, FStartDate);
end;

procedure TTransaction.Start(const AType, AName: string);
begin
  FStartDate := now;
  Ftimestamp := TTimestampEpoch.Get(FStartDate);
  Ftype := AType;
  Fname := AName;
end;

function TTransaction.ToJsonString: string;
var
  key:                       string;
  LJSONValue, Context, Tags: TJSONObject;
begin
  if (Self.Context = nil) then
    Exit(format(sTransactionJsonId, [TJson.ObjectToJsonString(Self, [joIgnoreEmptyStrings])]));

  LJSONValue := TJson.ObjectToJsonObject(Self, [joIgnoreEmptyStrings]);
  try
    if Self.Context.HasTags() then
    begin
      Context := LJSONValue.FindValue('context') as TJSONObject;
      Tags    := TJSONObject.Create;
      // manually add dynamic data to the json: using TJsonStringDictionaryConverter, JsonReflectAttribute, JsonConverterAttribute etc didn't work or too cumbersome or resulted in empty strings etc
      for key in Self.Context.Tags.Keys do
        Tags.AddPair(key, Self.Context.Tags[key]);
      Context.AddPair('tags', Tags);
    end;

    if (Self.Context.Request <> nil) and (Self.Context.Request.Headers <> nil) then
    begin
      Context := LJSONValue.FindValue('context.request') as TJSONObject;
      Tags    := TJSONObject.Create;
      for key in Self.Context.Request.Headers.Keys do
        Tags.AddPair(key, Self.Context.Request.Headers[key]);
      Context.AddPair('headers', Tags);

      Tags := TJSONObject.Create;
      for key in Self.Context.Request.Cookies.Keys do
        Tags.AddPair(key, Self.Context.Request.Cookies[key]);
      Context.AddPair('cookies', Tags);
    end;

    Result := format(sTransactionJsonId, [TJson.JsonEncode(LJSONValue)]);
  finally
    LJSONValue.Free;
  end;
end;

end.

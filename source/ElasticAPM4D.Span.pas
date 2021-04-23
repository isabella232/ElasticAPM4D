unit ElasticAPM4D.Span;

interface

uses
  System.SysUtils,
  System.JSON,
  ElasticAPM4D.Service,
  ElasticAPM4D.Stacktrace;

type
  TDB = class
  private
    FInstance:      string;
    FStatement:     string;
    FType:          string;
    FUser:          string;
    Flink:          string;
    Frows_affected: integer;
  public
    property instance:      string read FInstance write FInstance; // Instance name of the database
    property link:          string read Flink write Flink; // Link to the database server
    property statement:     string read FStatement write FStatement; // Statement of the recorded database event, e.g. query
    property &type:         string read FType write FType; // Type of the recorded database event., e.g. sql, cassandra, hbase, redis
    property user:          string read FUser write FUser; // User is the username with which the database is accessed
    property rows_affected: integer read Frows_affected write Frows_affected;
  end;

  THttp = class
  private
    FMethod:      string;
    FStatus_code: integer;
    FUrl:         string;
  public
    property method:      string read FMethod write FMethod;
    property status_code: integer read FStatus_code write FStatus_code;
    property url:         string read FUrl write FUrl;
  end;

  TService = class
  private
    FAgent: TAgent;
    FName:  string;
  public
    constructor Create;
    destructor Destroy; override;

    property Agent: TAgent read FAgent;
    property name: string read FName;
  end;

  TContext = class
  private
    FService: TService;
    FHttp:    THttp;
    FDb:      TDB;
    function GetHttp: THttp;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property Service: TService read FService write FService;
    property db: TDB read FDb write FDb;
    property http: THttp read GetHttp write FHttp;
  end;

  // https://github.com/elastic/apm-server/blob/v7.12.0/docs/spec/v2/span.json
  TSpan = class
  private
    FStartDate:      TDateTime;
    FAction:         string;
    FContext:        TContext;
    FDuration:       Int64;
    FId:             string;
    FName:           string;
    FParent_id:      string;
    FStacktrace:     TArray<TStacktrace>;
    FSubtype:        string;
    FSync:           Boolean;
    FTrace_id:       string;
    FTransaction_id: string;
    FType:           string;
    Ftimestamp:      Int64;
  public
    constructor Create(const ATraceId, ATransactionId, AParentId: string);
    destructor Destroy; override;

    function ToJsonString: string;

    procedure Start;
    procedure &End;

    property Id: string read FId;
    property Transaction_id: string read FTransaction_id;
    property name: string read FName write FName;
    property &type: string read FType write FType;
    property Parent_id: string read FParent_id;
    property Trace_id: string read FTrace_id;
    property Subtype: string read FSubtype write FSubtype;
    property Action: string read FAction write FAction;
    property Duration: Int64 read FDuration write FDuration;
    property Context: TContext read FContext write FContext;
    property Stacktrace: TArray<TStacktrace> read FStacktrace write FStacktrace;
    property Sync: Boolean read FSync write FSync default true;
    property Timestamp: Int64 read Ftimestamp;
  end;

implementation

uses
  System.DateUtils,
  REST.JSON,
  ElasticAPM4D.Utils,
  ElasticAPM4D.Resources;

{ TSpanService }

constructor TService.Create;
begin
  FAgent := TAgent.Create;
end;

destructor TService.Destroy;
begin
  FAgent.Free;
  inherited;
end;

{ TSpanContext }

constructor TContext.Create;
begin
  FService := TService.Create;
  FDb      := TDB.Create;
end;

destructor TContext.Destroy;
begin
  FService.Free;
  FDb.Free;
  FHttp.Free;
  inherited;
end;

function TContext.GetHttp: THttp;
begin
  if FHttp = nil then
    FHttp := THttp.Create;
  Result  := FHttp;
end;

{ TSpan }

constructor TSpan.Create(const ATraceId, ATransactionId, AParentId: string);
begin
  FId             := TUUid.Get64b;
  FTrace_id       := ATraceId;
  FTransaction_id := ATransactionId;
  FParent_id      := AParentId;
  FAction         := '';
  FSubtype        := '';
  FSync           := true;
  FContext        := TContext.Create;
end;

destructor TSpan.Destroy;
var
  LStack: TStacktrace;
begin
  for LStack in FStacktrace do
    LStack.Free;
  FreeAndNil(FContext);
  inherited;
end;

procedure TSpan.&End;
begin
  FDuration := MilliSecondsBetween(now, FStartDate);
end;

procedure TSpan.Start;
begin
  FStartDate := now;
  Ftimestamp := TTimestampEpoch.Get(FStartDate);
end;

function TSpan.ToJsonString: string;
begin
  Result := format(sSpanJsonId, [TJson.ObjectToJsonString(self, [joDateIsUTC, joIgnoreEmptyStrings])]);
end;

end.


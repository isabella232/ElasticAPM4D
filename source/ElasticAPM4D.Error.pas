unit ElasticAPM4D.Error;

interface

uses
  System.SysUtils,
  ElasticAPM4D.Stacktrace,
  ElasticAPM4D.Span;

type
  TException = class
  private
    FCode:       string;
    FHandled:    Boolean;
    FMessage:    string;
    FModule:     string;
    FStacktrace: TArray<TStacktrace>;
    FType:       string;
    Fattributes: TObject;
    Fparent:     Integer;
    Fcause:      TArray<TObject>;
  public
    destructor Destroy; override;

    property Attributes: TObject read Fattributes write Fattributes;
    property Cause: TArray<TObject> read Fcause write Fcause;
    property Code: string read FCode write FCode;
    property Handled: Boolean read FHandled write FHandled;
    property &Message: string read FMessage write FMessage;
    property Module: string read FModule write FModule;
    property Parent: Integer read Fparent write Fparent;
    property Stacktrace: TArray<TStacktrace> read FStacktrace write FStacktrace;
    property &Type: string read FType write FType;
  end;

  // https://github.com/elastic/apm-server/blob/v7.12.0/docs/spec/v2/error.json
  TError = class
  private
    FCulprit:        string;
    FException:      TException;
    FId:             string;
    FParent_id:      string;
    FTrace_id:       string;
    FTransaction_id: string;
    FTimestamp:      Int64;
    Fcontext:        TContext;
  public
    constructor Create(const ATraceId, ATransactionId, AParentId: string);
    destructor Destroy; override;

    function ToJsonString: string;
    procedure SetCulprit(const aExceptAddr: Pointer);

    property id: string read FId;
    property Timestamp: Int64 read FTimestamp;
    property Parent_id: string read FParent_id;
    property Trace_id: string read FTrace_id;
    property Transaction_id: string read FTransaction_id;
    property Culprit: string read FCulprit write FCulprit; // Culprit identifies the function call which was the primary perpetrator of this event.
    property Exception: TException read FException write FException;
  end;

implementation

uses
  Rest.Json,
  ElasticAPM4D.Utils,
{$IFDEF JCL}
  JclDebug,
  ElasticAPM4D.StackTraceJCL,
{$ENDIF}
  ElasticAPM4D.Resources;

{ TException }

destructor TException.Destroy;
var
  Item: TObject;
begin
  if Assigned(Fattributes) then
    Fattributes.Free;
  for Item in Fcause do
    Item.Free;
  inherited;
end;

{ TError }

constructor TError.Create(const ATraceId, ATransactionId, AParentId: string);
begin
  FId        := TUUid.Get128b;
  FException := TException.Create;
{$IFDEF JCL}
  FException.Stacktrace := TStacktraceJCL.Get;
  if FException.Stacktrace = nil then
  begin
    JclDebug.JclCreateStackList(False, -1, nil);
    FException.Stacktrace := TStacktraceJCL.Get;
  end;
{$ENDIF}
  FCulprit        := '';
  FTimestamp      := TTimestampEpoch.Get(now);
  FTrace_id       := ATraceId;
  FTransaction_id := ATransactionId;
  FParent_id      := AParentId;
end;

destructor TError.Destroy;
begin
  FException.Free;
  inherited;
end;

procedure TError.SetCulprit(const aExceptAddr: Pointer);
begin
{$IFDEF JCL}
  Culprit := JclDebug.GetLocationInfo(aExceptAddr).ProcedureName;
{$ENDIF}
end;

function TError.ToJsonString: string;
begin
  Result := format(sErrorJsonId, [TJson.ObjectToJsonString(self, [joIgnoreEmptyStrings, joIgnoreEmptyArrays])]);
end;

end.

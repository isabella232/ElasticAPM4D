unit ElasticAPM4D.Helpers;

interface

uses
  System.Classes,
  System.SysUtils,
  IdHTTP,
  ElasticAPM4D.Transaction,
  ElasticAPM4D.Span;

function StartTransaction(AIdHTTP: TIdHTTP; const AType, AName: string): TTransaction;
procedure SetTransactionHttpContext(AIdHTTP: TIdHTTP);
procedure EndTransaction(AIdHTTP: TIdHTTP);
function StartSpan(const AName: string): TSpan;
procedure EndSpan(AIdHTTP: TIdHTTP);
{$IFDEF dmvcframework}
class function StartTransaction(AActionName: string; AContext: TWebContext): TTransaction; overload;
class procedure EndTransaction(const ARESTClient: MVCFramework.RESTClient.TRESTClient; const AResponse: IRESTResponse; const AHttpMethod: string); overload;
class procedure EndTransaction(const AContext: TWebContext); overload;
{$ENDIF}

type
  TIdHttpAPM = class(TIdHTTP)
  protected
    procedure DoRequest(const AMethod: TIdHTTPMethod; aUrl: string; ASource, AResponseContent: TStream; AIgnoreReplies: array of Int16); override;
  end;

implementation

uses
  ElasticAPM4D,
  ElasticAPM4D.Context,
  ElasticAPM4D.Request,
  ElasticAPM4D.Error;

function StartTransaction(AIdHTTP: TIdHTTP; const AType, AName: string): TTransaction;
begin
  if TElasticAPM4D.ExistsTransaction then
    Result := TElasticAPM4D.CurrentTransaction
  else
    Result := TElasticAPM4D.StartTransaction(AType, AName);
end;

procedure SetTransactionHttpContext(AIdHTTP: TIdHTTP);
var
  Transaction: TTransaction;
begin
  Transaction := TElasticAPM4D.CurrentTransaction;
  if Transaction = nil then
    Exit;

  if Transaction.Context = nil then
    Transaction.Context := TContext.Create();
  if Transaction.Context.Request = nil then
    Transaction.Context.Request            := TRequest.Create;
  Transaction.Context.Request.url.Hostname := AIdHTTP.url.Host;
  Transaction.Context.Request.url.Full     := AIdHTTP.url.GetFullURI;
  Transaction.Context.Request.url.Protocol := AIdHTTP.url.Protocol;
  Transaction.Context.Request.url.Pathname := AIdHTTP.url.Path;
  Transaction.Context.Request.url.port     := StrToIntDef(AIdHTTP.url.port, 0);
  Transaction.Context.Request.url.Search   := AIdHTTP.url.Params;
  Transaction.Context.Request.url.Raw      := AIdHTTP.url.URI;
  Transaction.Context.Request.Method       := AIdHTTP.Request.Method;
end;

procedure EndTransaction(AIdHTTP: TIdHTTP);
begin
  if not TElasticAPM4D.ExistsTransaction then
    Exit;

  TElasticAPM4D.CurrentTransaction.Context.Response := TResponse.Create;
  TElasticAPM4D.CurrentTransaction.Context.Response.finished := True;
  TElasticAPM4D.CurrentTransaction.Context.Response.headers_sent := AIdHTTP.Request.CustomHeaders.Count > 0;
  TElasticAPM4D.CurrentTransaction.Context.Response.status_code := AIdHTTP.ResponseCode;

  TElasticAPM4D.EndTransaction;
end;

function StartSpan(const AName: string): TSpan;
begin
  Result := TElasticAPM4D.StartCustomSpan(AName, 'Request');
end;

procedure EndSpan(AIdHTTP: TIdHTTP);
begin
  TElasticAPM4D.CurrentSpan.Context.http             := THttp.Create;
  TElasticAPM4D.CurrentSpan.Context.http.Method      := AIdHTTP.Request.Method;
  TElasticAPM4D.CurrentSpan.Context.http.status_code := AIdHTTP.ResponseCode;
  TElasticAPM4D.CurrentSpan.Context.http.url         := AIdHTTP.url.URI;
  TElasticAPM4D.EndSpan;
end;

{$IFDEF dmvcframework}

class function TElasticAPM4D.StartTransaction(AActionName: string; AContext: TWebContext): TTransaction;
begin
  Result          := StartCustomTransaction('DMVCFramework', AActionName);
  FPackage.Header := AContext.Request.Headers[HeaderKey];
end;

class procedure TElasticAPM4D.EndTransaction(const ARESTClient: MVCFramework.RESTClient.TRESTClient; const AResponse: IRESTResponse; const AHttpMethod: string);
var
  LError: TError;
begin
  CurrentTransaction.Context.AutoConfigureContext(AResponse);
  CurrentTransaction.Context.Request.url.Full := ARESTClient.url;
  CurrentTransaction.Context.Request.Method   := AHttpMethod;
  if AResponse.HasError then
  begin
    LError := GetError;

    LError.Exception.Code    := AResponse.Error.HTTPError.ToString;
    LError.Exception.&Type   := AResponse.Error.ExceptionClassname;
    LError.Exception.Message := AResponse.Error.ExceptionMessage;

    AddError(LError);
    EndTransaction('failure');
  end
  else
    EndTransaction;
end;

class procedure TElasticAPM4D.EndTransaction(const AContext: TWebContext);
begin
  CurrentTransaction.Context.AutoConfigureContext(AContext);
  EndTransaction;
end;

{$ENDIF}
//
// { TIdHTTP }
//
// procedure TIdHTTP.DoRequest(const AMethod: TIdHTTPMethod; AURL: string;
// ASource, AResponseContent: TStream; AIgnoreReplies: array of Int16);
// var
// HasTransaction: Boolean;
// LName: string;
// begin
// HasTransaction := TElasticAPM4D.ExistsTransaction;
// LName := AURL;
// if not HasTransaction then
// begin
// TElasticAPM4D.StartTransaction('Indy', AURL);
// LName := 'DoRequest';
// end;
// // TElasticAPM4D.StartSpan(Self, LName);
// try
// Try
// inherited;
// except
// // on E: EIdHTTPProtocolException do
// // begin
// // TElasticAPM4D.AddError(Self, E);
// // raise;
// // end;
// on E: Exception do
// begin
// TElasticAPM4D.AddError(E);
// raise;
// end;
// end;
// Finally
// // TElasticAPM4D.EndSpan(Self);
// if not HasTransaction then
// TElasticAPM4D.EndTransaction;
// End;
// end;
//
// { TContext }
//
// constructor TContext.Create(AIdHTTP: TIdHTTP);
// var
// I: Integer;
// begin
// inherited Create;
// FIdHTTP := AIdHTTP;
//
// Page := TPage.Create;
// Page.referer := AIdHTTP.Request.referer;
// Page.url := AIdHTTP.Request.url;
//
// Request := TRequest.Create;
//
// Request.Method := AIdHTTP.Request.Method;
// Request.Http_version := AIdHTTP.Version;
// Request.Socket.encrypted := Assigned(AIdHTTP.Socket);
//
// Request.url.Hostname := AIdHTTP.url.Host;
// Request.url.full := AIdHTTP.url.GetFullURI;
// Request.url.protocol := AIdHTTP.url.protocol;
// Request.url.pathname := AIdHTTP.url.Path;
// Request.url.port := StrToIntDef(AIdHTTP.url.port, 0);
// Request.url.search := AIdHTTP.url.Params;
// Request.url.raw := AIdHTTP.url.Document;
//
// for I := 0 to pred(AIdHTTP.Request.CustomHeaders.Count) do
// Request.headers := Request.headers + ', ' + AIdHTTP.Request.CustomHeaders.Strings[I];
//
// if not Request.headers.isEmpty then
// Request.headers := Request.headers.Remove(1, 1);
// end;
//
// procedure TContext.FillResponse;
// begin
// Response := TResponse.Create;
// Response.finished := True;
// Response.headers_sent := FIdHTTP.Response.CustomHeaders.Count > 0;
// Response.status_code := FIdHTTP.ResponseCode;
// end;

{ TIdHttpAPM }

procedure TIdHttpAPM.DoRequest(const AMethod: TIdHTTPMethod; aUrl: string; ASource, AResponseContent: TStream; AIgnoreReplies: array of Int16);
begin
  try
    if TElasticAPM4D.ExistsTransaction() then
    begin
      ElasticAPM4D.Helpers.StartSpan(aUrl);
      Self.Request.CustomHeaders.AddValue('Traceparent', TElasticAPM4D.HeaderValue);
    end;

    try
      inherited DoRequest(AMethod, aUrl, ASource, AResponseContent, AIgnoreReplies);
    except
      on E: EIdHTTPProtocolException do
        TElasticAPM4D.AddError(E);
      on E: Exception do
        TElasticAPM4D.AddError(E);
    end;
  finally
    if TElasticAPM4D.ExistsTransaction() then
      ElasticAPM4D.Helpers.EndSpan(Self);
  end;
end;

end.

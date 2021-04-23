unit ElasticAPM4D.Helpers;

interface

uses
  System.Classes,
  System.SysUtils,
  IdHTTP,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
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
  TIdHTTPServer_Helper = class helper for TIdHTTPServer
  public type
    THandleRequestCallback = procedure(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo) of object;
  public
    procedure PreProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo);
    procedure ProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; ACallback: THandleRequestCallback);
    procedure PostProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  end;

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
{ TIdHTTPServer_Helper }

procedure TIdHTTPServer_Helper.ProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo;
  ACallback: THandleRequestCallback);
begin
  try
    PreProcessRequest(AContext, ARequestInfo);
    try
      ACallback(AContext, ARequestInfo, AResponseInfo);
    except
      on E: Exception do
        TElasticAPM4D.AddError(E);
    end;
  finally
    PostProcessRequest(AContext, ARequestInfo, AResponseInfo);
  end;
end;

{ TIdHTTPServer_Helper }

procedure TIdHTTPServer_Helper.PreProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo);
begin
    if TElasticAPM4D.IsRecording then
    begin
    if ARequestInfo.RawHeaders.Values['X-Correlation-ID'] <> '' then
      TElasticAPM4D.StartTransaction('http', ARequestInfo.Document, ARequestInfo.RawHeaders.Values['X-Correlation-ID'])
    else
      TElasticAPM4D.StartTransaction('http', ARequestInfo.Document);

    if ARequestInfo.RawHeaders.Values['Traceparent'] <> '' then
      TElasticAPM4D.HeaderValue := ARequestInfo.RawHeaders.Values['Traceparent'];
  end;
end;

procedure TIdHTTPServer_Helper.PostProcessRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  i: Integer;
      begin
  if TElasticAPM4D.ExistsTransaction then
  begin
    if TElasticAPM4D.ExistsError() or // always store errors
      (TElasticAPM4D.CurrentTransaction.GetCurrentDuration() >= 1 * 1000) or // store slow calls (1s)
      (ARequestInfo.RawHeaders.Values['Traceparent'] <> '') or (ARequestInfo.RawHeaders.Values['X-Correlation-ID'] <> '') or // store external trace request
      (TElasticAPM4D.TransactionSampleRate >= 1) or (Random(100) <= TElasticAPM4D.TransactionSampleRate * 100) // store limited % of calls
    then
      // store details only when not discarded (to reduce overhead of small and not-recorded calls)
      with TElasticAPM4D.CurrentTransaction do
      begin
        // request handling
        Context.Request.url.Hostname := ARequestInfo.Host;
        Context.Request.url.Full     := ARequestInfo.URI;
        Context.Request.url.Protocol := 'http'; // ARequestInfo.Version; // AIdHTTP.url.protocol;
        Context.Request.url.Pathname := ARequestInfo.Document;
        Context.Request.url.port     := AContext.Binding.port;
        Context.Request.url.Search   := ARequestInfo.Params.Text;
        Context.Request.url.Raw      := ARequestInfo.RawHTTPCommand;
        Context.Request.Method       := HTTPRequestStrings[Ord(ARequestInfo.CommandType)];
        Context.Request.Http_version := ARequestInfo.Version;
        // Context.Request.Socket.Encrypted := TODO
        Context.Request.Socket.Remote_address := ARequestInfo.RemoteIP;

        Context.Page.Referer := ARequestInfo.Referer;
        Context.Page.url     := ARequestInfo.URI;

        if TElasticAPM4D.IsCaptureBody and (ARequestInfo.PostStream <> nil) then
          with TStreamReader.Create(ARequestInfo.PostStream) do
            try
              Context.Request.Body := ReadToEnd();
            finally
              Free;
            end;

        if TElasticAPM4D.IsCaptureHeaders then
        begin
          for i := 0 to ARequestInfo.RawHeaders.Count - 1 do
            Context.Request.Headers.AddOrSetValue(ARequestInfo.RawHeaders.Names[i], ARequestInfo.RawHeaders.ValueFromIndex[i]);
          for i := 0 to ARequestInfo.Cookies.Count - 1 do
            Context.Request.Cookies.AddOrSetValue(ARequestInfo.Cookies.Cookies[i].CookieName, ARequestInfo.Cookies[i].CookieText);
        end;

        // response handling
          Context.Response.finished     := True;
          Context.Response.headers_sent := AResponseInfo.CustomHeaders.Count > 0;
          Context.Response.status_code  := AResponseInfo.ResponseNo;

          if TElasticAPM4D.IsCaptureHeaders then
          begin
            for i := 0 to AResponseInfo.RawHeaders.Count - 1 do
              Context.Response.Headers.AddOrSetValue(AResponseInfo.RawHeaders.Names[i], AResponseInfo.RawHeaders.ValueFromIndex[i]);
          end;

        TElasticAPM4D.EndTransaction();
        end
      else
        TElasticAPM4D.ClearTransaction();
  end;
end;

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

initialization

Randomize();

end.

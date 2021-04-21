unit dmHttp;

interface

uses
  System.SysUtils,
  System.Classes,
  IdContext,
  IdBaseComponent,
  IdComponent,
  IdCustomTCPServer,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdExceptionCore,
  IdException;

type
  TDataModule2 = class(TDataModule)
    IdHTTPServer1: TIdHTTPServer;
    procedure IdHTTPServer1Exception(AContext: TIdContext; AException: Exception);
    procedure IdHTTPServer1CommandOther(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure IdHTTPServer1CommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
    procedure DataModuleCreate(Sender: TObject);
  protected
    procedure HandleRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  protected
    procedure TestAsync(const aTraceParent: string);
  public
  end;

var
  DataModule2: TDataModule2;

implementation

uses
  ElasticAPM4D,
  ElasticAPM4D.Context,
  ElasticAPM4D.Request;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDataModule2.DataModuleCreate(Sender: TObject);
begin
  IdHTTPServer1.DefaultPort := 12345;
end;

procedure TDataModule2.HandleRequest(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  if ARequestInfo.Document = '/api/v1/test/sleep' then
  begin
    Sleep(ARequestInfo.Params.Values['duration'].ToInteger());
  end
  else if ARequestInfo.Document = '/api/v1/test/async' then
  begin
    TestAsync(ARequestInfo.RawHeaders.Values['Traceparent']);
  end
  else if ARequestInfo.Document = '/api/v1/test/error' then
  begin
    raise Exception.Create('Error Message');
  end
  else if ARequestInfo.Document = '/api/v1/test/tags' then
  begin
    if not TElasticAPM4D.ExistsTransaction() then
      Exit;

    if TElasticAPM4D.CurrentTransaction.Context = nil then
      TElasticAPM4D.CurrentTransaction.Context := ElasticAPM4D.Context.TContext.Create;
    TElasticAPM4D.CurrentTransaction.Context.Tags.AddOrSetValue(ARequestInfo.Params.Names[0], ARequestInfo.Params.ValueFromIndex[0]);
  end;
end;

procedure TDataModule2.IdHTTPServer1CommandError(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo; AException: Exception);
begin
  if TElasticAPM4D.ExistsTransaction() then
  begin
    TElasticAPM4D.AddError(AException);
    TElasticAPM4D.LastError.Culprit := ARequestInfo.Document;
  end
  else
  begin
    TElasticAPM4D.StartTransaction('server error', 'IdHTTPServer1Exception');
    TElasticAPM4D.AddError(AException);
    TElasticAPM4D.LastError.Culprit := ARequestInfo.Document;
    TElasticAPM4D.EndTransaction();
  end;
end;

procedure TDataModule2.IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  IdHTTPServer1CommandOther(AContext, ARequestInfo, AResponseInfo);
end;

procedure TDataModule2.IdHTTPServer1CommandOther(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  i: Integer;
begin
  try
    if TElasticAPM4D.IsRecording then
    begin
      with TElasticAPM4D.StartTransaction('http', ARequestInfo.Document) do
      begin
        if Context = nil then
          Context := TContext.Create();
        if Context.Request = nil then
          Context.Request := TRequest.Create();

        Context.Request.url.Hostname := ARequestInfo.Host;
        Context.Request.url.Full     := ARequestInfo.URI;
        Context.Request.url.Protocol := ARequestInfo.Version;
        Context.Request.url.Pathname := ARequestInfo.Document;
        Context.Request.url.port     := Self.IdHTTPServer1.DefaultPort;
        Context.Request.url.Search   := ARequestInfo.Params.Text;
        Context.Request.url.Raw      := ARequestInfo.RawHTTPCommand;
        Context.Request.Method       := HTTPRequestStrings[Ord(ARequestInfo.CommandType)];

        if TElasticAPM4D.IsCaptureBody and (ARequestInfo.PostStream <> nil) then
          with TStreamReader.Create(ARequestInfo.PostStream) do
            try
              Context.Request.Body := ReadToEnd();
            finally
              Free;
            end;

        if TElasticAPM4D.IsCaptureHeaders then
        begin
          if Context.Request.Headers = nil then
            Context.Request.Headers := TKeyValues.Create();
          if Context.Request.Cookies = nil then
            Context.Request.Cookies := TKeyValues.Create();

          for i := 0 to ARequestInfo.RawHeaders.Count - 1 do
            Context.Request.Headers.AddOrSetValue(ARequestInfo.RawHeaders.Names[i], ARequestInfo.RawHeaders.ValueFromIndex[i]);
          for i := 0 to ARequestInfo.Cookies.Count - 1 do
            Context.Request.Cookies.AddOrSetValue(ARequestInfo.Cookies.Cookies[i].CookieName, ARequestInfo.Cookies[i].CookieText);
        end;

        Context.Request.Http_version := ARequestInfo.Version;

        // Context.Request.Socket.Encrypted := TODO
        Context.Request.Socket.Remote_address := ARequestInfo.RemoteIP;
      end;
      if ARequestInfo.RawHeaders.Values['Traceparent'] <> '' then
        TElasticAPM4D.HeaderValue := ARequestInfo.RawHeaders.Values['Traceparent'];
    end;

    if LowerCase(ARequestInfo.Connection) = 'keep-alive' then
      AResponseInfo.CloseConnection := False
    else
      AResponseInfo.CloseConnection := True;

    try
      Writeln(ARequestInfo.Document);
      HandleRequest(AContext, ARequestInfo, AResponseInfo);
    except
      on E: Exception do
        TElasticAPM4D.AddError(E);
    end;
  finally
    if TElasticAPM4D.ExistsTransaction then
    begin
      if TElasticAPM4D.ExistsError() or // always store errors
        (TElasticAPM4D.CurrentTransaction.GetCurrentDuration() >= 1 * 1000) or // store slow calls (1s)
        (TElasticAPM4D.TransactionSampleRate >= 1) or (Random(100) <= TElasticAPM4D.TransactionSampleRate * 100) // store limited % of calls
      then
        TElasticAPM4D.EndTransaction()
      else
        TElasticAPM4D.ClearTransaction();
    end;
  end;
end;

procedure TDataModule2.IdHTTPServer1Exception(AContext: TIdContext; AException: Exception);
begin
  if AException is EIdSilentException then
    Exit;

  if TElasticAPM4D.ExistsTransaction() then
    TElasticAPM4D.AddError(AException)
  else
  begin
    TElasticAPM4D.StartTransaction('server error', 'IdHTTPServer1Exception');
    TElasticAPM4D.AddError(AException);
    TElasticAPM4D.EndTransaction();
  end;
end;

procedure TDataModule2.TestAsync(const aTraceParent: string);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(150);

      TElasticAPM4D.StartTransaction('backgroundjob', 'TestAsync');
      if aTraceParent <> '' then
        TElasticAPM4D.HeaderValue := aTraceParent;

      Sleep(50);

      TElasticAPM4D.EndTransaction();
    end).Start();
end;

end.

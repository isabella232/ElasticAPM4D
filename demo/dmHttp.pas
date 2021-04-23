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
  IdException,
  ElasticAPM4D.Helpers;

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
  Writeln(ARequestInfo.Document);

  if LowerCase(ARequestInfo.Connection) = 'keep-alive' then
    AResponseInfo.CloseConnection := False
  else
    AResponseInfo.CloseConnection := True;

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

procedure TDataModule2.IdHTTPServer1CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  IdHTTPServer1.ProcessRequest(AContext, ARequestInfo, AResponseInfo, Self.HandleRequest);
end;

procedure TDataModule2.IdHTTPServer1CommandOther(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  IdHTTPServer1.ProcessRequest(AContext, ARequestInfo, AResponseInfo, Self.HandleRequest);
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

unit Unit1;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  ElasticAPM4D,
  ElasticAPM4D.Utils,
  Vcl.StdCtrls,
  System.JSON,
  ElasticAPM4D.Context,
  System.Diagnostics,
  IdComponent,
  IdHTTP,
  IdIOHandlerStack,
  IdIntercept,
  IdGlobal,
  IdBaseComponent;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Button8: TButton;
    Button9: TButton;
    IdConnectionIntercept1: TIdConnectionIntercept;
    Label2: TLabel;
    edtTagServer: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure IdConnectionIntercept1Send(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);
  private
    function GetHttpData(const aUrl: string): string;
  public
  end;

var
  Form1: TForm1;

implementation

uses
  ElasticAPM4D.Helpers;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
  watch: TStopwatch;
begin
  watch := TStopwatch.Create();
  watch.Start();
  TElasticAPM4D.StartTransaction('test type', 'test transaction'); // , 'test trace id');
  watch.Stop();
  OutputDebugString(pchar(format('StartTransaction = %4.2fms', [watch.Elapsed.TotalMilliseconds])));
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  TElasticAPM4D.AddUser('user_id', 'username', 'user@mail');
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  TElasticAPM4D.AddDataBase('sql', 'db server instance', 'db user');
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  if not TElasticAPM4D.ExistsTransaction then
    TElasticAPM4D.StartTransaction('span trans', 'test span');

  TElasticAPM4D.StartSpan('test span', 'select *');
  // Sleep(100);
  // apm.EndSpan;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  TElasticAPM4D.AddError(exception.Create('test error'));
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  TElasticAPM4D.CurrentSpan.&End;
end;

procedure TForm1.Button7Click(Sender: TObject);
begin
  if Edit1.Text <> '' then
  begin
    if TElasticAPM4D.CurrentTransaction.Context = nil then
      TElasticAPM4D.CurrentTransaction.Context := ElasticAPM4D.Context.TContext.Create;
    TElasticAPM4D.CurrentTransaction.Context.Tags.AddOrSetValue('client_id', Edit1.Text);
  end;

  with TStopwatch.Create do
  begin
    Start();
    TElasticAPM4D.EndTransaction();
    Stop();
    OutputDebugString(pchar(format('EndTransaction = %4.2fms', [Elapsed.TotalMilliseconds])));
  end;
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  raise exception.Create('Raised test error message');
end;

procedure TForm1.Button9Click(Sender: TObject);
begin
  TElasticAPM4D.StartTransaction('client', 'Test trace calls');
  try
    if edtTagServer.Text <> '' then
    begin
      if TElasticAPM4D.CurrentTransaction.Context = nil then
        TElasticAPM4D.CurrentTransaction.Context := ElasticAPM4D.Context.TContext.Create;
      TElasticAPM4D.CurrentTransaction.Context.Tags.AddOrSetValue('tag_id', edtTagServer.Text);
      GetHttpData('http://localhost:12345/api/v1/test/tags?tag_id=' + edtTagServer.Text);
    end;

    GetHttpData('http://localhost:12345/api/v1/test/sleep?duration=100');
    GetHttpData('http://localhost:12345/api/v1/test/sleep?duration=10');
    GetHttpData('http://localhost:12345/api/v1/test/error');
    GetHttpData('http://localhost:12345/api/v1/test/async');
  finally
    TElasticAPM4D.EndTransaction();
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  TConfig.Environment := 'dev';
  // TConfig.SetUrlElasticAPM('http://127.0.0.1:8200/intake/v2/events');
end;

function TForm1.GetHttpData(const aUrl: string): string;
var
  http: TIdHTTP;
begin
  http := TIdHttpAPM.Create(Self);
  try
    // http.Intercept          := Self.IdConnectionIntercept1;
    // http.Request.Connection := 'keep-alive';
    Result := http.Get(aUrl);
  finally
    http.Free;
  end;
end;

procedure TForm1.IdConnectionIntercept1Send(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);
begin
  if not TElasticAPM4D.ExistsTransaction() then
    StartTransaction(ASender.Connection as TIdHTTP, 'http', (ASender.Connection as TIdHTTP).Request.URL);
  // note: this is actually meant for the server side
  SetTransactionHttpContext(ASender.Connection as TIdHTTP);
end;

end.

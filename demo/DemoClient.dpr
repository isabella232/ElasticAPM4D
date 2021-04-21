program DemoClient;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  ElasticAPM4D in '..\source\ElasticAPM4D.pas',
  ElasticAPM4D.Utils in '..\source\ElasticAPM4D.Utils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

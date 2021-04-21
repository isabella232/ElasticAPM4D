program DemoServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ElasticAPM4D.Utils,
  dmHttp in 'dmHttp.pas' {DataModule2: TDataModule};

begin
  try
    TConfig.Environment := 'dev';

    DataModule2                      := TDataModule2.Create(nil);
    DataModule2.IdHTTPServer1.Active := True;

    WriteLn('Server started');
    ReadLn;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

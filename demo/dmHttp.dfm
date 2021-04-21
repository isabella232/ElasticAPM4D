object DataModule2: TDataModule2
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  Height = 150
  Width = 215
  object IdHTTPServer1: TIdHTTPServer
    Bindings = <>
    OnException = IdHTTPServer1Exception
    OnCommandError = IdHTTPServer1CommandError
    OnCommandOther = IdHTTPServer1CommandOther
    OnCommandGet = IdHTTPServer1CommandGet
    Left = 88
    Top = 56
  end
end

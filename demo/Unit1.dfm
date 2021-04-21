object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 301
  ClientWidth = 394
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 124
    Top = 115
    Width = 22
    Height = 13
    Caption = 'Tag:'
  end
  object Label2: TLabel
    Left = 124
    Top = 271
    Width = 22
    Height = 13
    Caption = 'Tag:'
  end
  object Button1: TButton
    Left = 8
    Top = 110
    Width = 97
    Height = 25
    Caption = 'Start trans'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 8
    Top = 8
    Width = 97
    Height = 25
    Caption = 'Set User (global)'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 8
    Top = 39
    Width = 97
    Height = 25
    Caption = 'Set DB (global)'
    TabOrder = 2
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 30
    Top = 141
    Width = 75
    Height = 25
    Caption = 'Start span'
    TabOrder = 3
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 30
    Top = 172
    Width = 75
    Height = 25
    Caption = 'Add error'
    TabOrder = 4
    OnClick = Button5Click
  end
  object Button6: TButton
    Left = 123
    Top = 141
    Width = 75
    Height = 25
    Caption = 'Span stop'
    TabOrder = 5
    OnClick = Button6Click
  end
  object Button7: TButton
    Left = 281
    Top = 110
    Width = 97
    Height = 25
    Caption = 'Trans end'
    TabOrder = 6
    OnClick = Button7Click
  end
  object Edit1: TEdit
    Left = 152
    Top = 112
    Width = 112
    Height = 21
    TabOrder = 7
  end
  object Button8: TButton
    Left = 8
    Top = 203
    Width = 75
    Height = 25
    Caption = 'Raise error'
    TabOrder = 8
    OnClick = Button8Click
  end
  object Button9: TButton
    Left = 8
    Top = 268
    Width = 97
    Height = 25
    Caption = 'Http calls to server'
    TabOrder = 9
    OnClick = Button9Click
  end
  object edtTagServer: TEdit
    Left = 152
    Top = 268
    Width = 112
    Height = 21
    TabOrder = 10
  end
  object IdConnectionIntercept1: TIdConnectionIntercept
    OnSend = IdConnectionIntercept1Send
    Left = 184
    Top = 256
  end
end

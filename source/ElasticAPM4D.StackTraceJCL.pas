unit ElasticAPM4D.StackTraceJCL;

interface

uses
  System.Classes,
  ElasticAPM4D.Stacktrace;

type
  TStacktraceJCL = class
  public
    class function Get: TArray<TStacktrace>;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  JclDebug,
{$ENDIF} System.IOUtils,
  System.SysUtils;

{ TStacktraceJCL }

class function TStacktraceJCL.Get: TArray<TStacktrace>;
var
  Stacktrace: TStacktrace;
  Line:       Integer;
  StackList:  TJclStackInfoList;
  Info:       TJclLocationInfo;
begin
  StackList := JclLastExceptStackList;
  if StackList = nil then
    Exit;
  try
    for Line := 0 to Pred(StackList.Count) do
    begin
      if GetLocationInfo(StackList[Line].CallerAddr, Info) then
      begin
        Stacktrace           := TStacktrace.Create;
        Stacktrace.lineno    := Info.LineNumber;
        Stacktrace.module    := Info.BinaryFileName;
        Stacktrace.&function := Info.ProcedureName;
        Stacktrace.Filename  := Info.UnitName;
        Stacktrace.Abs_path  := Info.SourceName;
        if (Info.UnitName <> '') and ( //
          Info.UnitName.StartsWith('System') or Info.UnitName.StartsWith('Winapi.') or Info.UnitName.StartsWith('Vcl.') or Info.UnitName.StartsWith('FMX.') or
          Info.UnitName.StartsWith('Data.') or Info.UnitName.StartsWith('FireDAC.') or Info.UnitName.StartsWith('Soap.') or Info.UnitName.StartsWith('Xml.') or
          Info.UnitName.StartsWith('Xml.') or Info.UnitName.StartsWith('ElasticAPM4D') or Info.UnitName.StartsWith('JclDebug') or
          Info.UnitName.StartsWith('JclHookExcept')) then
        begin
          Stacktrace.library_frame := True;
        end;
        Result := Result + [Stacktrace];
      end;
    end;
  finally
    StackList.Free;
  end;
end;

end.

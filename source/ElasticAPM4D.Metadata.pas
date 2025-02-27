unit ElasticAPM4D.Metadata;

interface

uses
  ElasticAPM4D.Service,
  ElasticAPM4D.User;

type
  TProcess = class
  private
    FArgv:  TArray<string>;
    FPid:   Cardinal;
    FPpid:  Integer;
    Ftitle: string;
{$IFDEF MSWINDOWS}
    function GetParentProcessId: longint;
    function GetProcessId: longint;
    function GetProcessName: string;
{$ENDIF}
  public
    constructor Create;

    property Argv: TArray<string> read FArgv write FArgv;
    property Pid: Cardinal read FPid;
    property Ppid: Integer read FPpid;
    property Title: string read Ftitle;
  end;

  TSystem = class
  private
    FArchitecture: string;
    FHostname:     string;
    FPlatform:     string;
    function GetHostNameInOS: string;
  public
    constructor Create;

    property Architecture: string read FArchitecture;
    property Hostname: string read FHostname;
    property &Platform: string read FPlatform;
  end;

  // https://github.com/elastic/apm-server/blob/v7.12.0/docs/spec/v2/metadata.json
  TMetadata = class
  private
    FProcess: TProcess;
    FService: TService;
    FSystem:  TSystem;
    FUser:    TUser;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToJsonString: string;

    property Process: TProcess read FProcess;
    property Service: TService read FService;
    property System: TSystem read FSystem;
    property User: TUser read FUser write FUser;
  end;

implementation

uses
{$IFDEF MSWINDOWS} TLHelp32,
  psAPI,
  Winapi.Windows,
  Vcl.Forms, {$ENDIF}
{$IFDEF UNIX} Unix, {$ENDIF}
  System.SysUtils,
  Rest.Json,
  ElasticAPM4D.Resources;

constructor TProcess.Create;
begin
{$IFDEF MSWINDOWS}
  Ftitle := GetProcessName;
  FPid   := GetProcessId;
  FPpid  := GetParentProcessId;
{$ENDIF}
end;

{$IFDEF MSWINDOWS}

function TProcess.GetProcessId: longint;
begin
  Result := GetCurrentProcessId();
end;

function TProcess.GetProcessName: string;
var
  LProcess: THandle;
  LModName: array [0 .. MAX_PATH + 1] of Char;
begin
  Result   := Application.Title;
  LProcess := OpenProcess(PROCESS_ALL_ACCESS, False, FPid);
  try
    if LProcess <> 0 then
      if GetModuleFileName(LProcess, LModName, SizeOf(LModName)) <> 0 then
        Result := LModName;
  finally
    CloseHandle(LProcess);
  end;
end;

function TProcess.GetParentProcessId: longint;
var
  Snapshot: THandle;
  Entry:    TProcessEntry32;
  NotFound: Boolean;
begin
  Result := 0;

  Snapshot := CreateToolHelp32SnapShot(TH32CS_SNAPPROCESS, 0);
  if Snapshot <> 0 then
  begin
    FillChar(Entry, SizeOf(Entry), 0);
    Entry.dwSize := SizeOf(Entry);
    NotFound     := Process32First(Snapshot, Entry);
    while NotFound do
    begin
      if Entry.th32ProcessID = FPid then
      begin
        Result := Entry.th32ParentProcessID;
        Break;
      end;
      NotFound := Process32Next(Snapshot, Entry);
    end;
    CloseHandle(Snapshot);
  end;
end;
{$ENDIF}
{ TSystem }

function TSystem.GetHostNameInOS: string;
{$IFDEF MSWINDOWS}
var
  l: DWORD;
{$ENDIF}
begin
{$IFDEF UNIX}
  Result := Unix.GetHostName;
{$ENDIF}
{$IFDEF MSWINDOWS}
  l := 255;
  SetLength(Result, l);
  GetComputerName(PChar(Result), l);
  SetLength(Result, l);
{$ENDIF}
end;

constructor TSystem.Create;
const
  ARQHITECTURE: array [TOSVersion.TArchitecture] of string = ('IntelX86', 'IntelX64', 'ARM32', 'ARM64');
begin
  FArchitecture := ARQHITECTURE[TOSVersion.Architecture];
  FHostname     := GetHostNameInOS;
  FPlatform     := TOSVersion.ToString;
end;

{ TMetadata }

constructor TMetadata.Create;
begin
  FService := TService.Create;
  FSystem  := TSystem.Create;
  FUser    := TUser.Create;
  FProcess := TProcess.Create;
end;

destructor TMetadata.Destroy;
begin
  FService.Free;
  FSystem.Free;
  FUser.Free;
  FProcess.Free;
  inherited;
end;

function TMetadata.ToJsonString: string;
begin
  Result := format(sMetadataJsonId, [TJson.ObjectToJsonString(self)]);
end;

end.

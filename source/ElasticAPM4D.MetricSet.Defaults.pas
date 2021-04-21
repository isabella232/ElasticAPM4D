unit ElasticAPM4D.MetricSet.Defaults;

interface

uses
  REST.Json.Types,
  ElasticAPM4D.MetricSet,
  Winapi.ActiveX,
  System.Classes;

type
  TDiskInfo = record
    Usage: Int64;
    FreeSpace: Int64;
  end;

  TMetricsetDefaults = class
{$IFDEF MSWINDOWS}
    class function MemoryUsage: Int64;
    class function DiskInfo: TDiskInfo;
{$ENDIF}
  end;

  TBaseMetric = class(TBaseSampleSet)
  private
    class var FSystemTimes: TThread.TSystemTimes;
  public
    // Disk_Usage: TSample;  no default Kibana metric for this?
    // Disk_FreeSpace: TSample;

    [JsonNameAttribute('system.process.memory.size')]
    Memory_Usage: TSample;
    [JsonNameAttribute('system.process.memory.rss.bytes')]
    Memory_Workingset: TSample;

    [JsonNameAttribute('system.memory.total')]
    System_Memory: TSample;
    [JsonNameAttribute('system.memory.actual.free')]
    System_Memory_Free: TSample;

    [JsonNameAttribute('system.process.cpu.total.norm.pct')]
    System_CPU_Process: TSample;
    [JsonNameAttribute('system.cpu.total.norm.pct')]
    System_CPU: TSample;

    constructor Create; virtual;
    destructor Destroy; override;

    class constructor Create;
  end;

implementation

{$IFDEF MSWINDOWS}

uses
  ComObj,
  Variants,
  TLHelp32,
  psAPI,
  Winapi.Windows,
  System.SysUtils;
{$ENDIF}
{ TMetricsetDefaults }

{$IFDEF MSWINDOWS}

class function TMetricsetDefaults.MemoryUsage: Int64;
var
  pmc: PPROCESS_MEMORY_COUNTERS;
  cb:  Integer;
begin
  Result := 0;
  cb     := SizeOf(TProcessMemoryCounters);
  GetMem(pmc, cb);
  pmc^.cb := cb;
  if GetProcessMemoryInfo(GetCurrentProcess(), pmc, cb) then
    Result := longint(pmc^.WorkingSetSize);
  FreeMem(pmc);
end;

class function TMetricsetDefaults.DiskInfo: TDiskInfo;
const
  WbemUser            = '';
  WbemPassword        = '';
  WbemComputer        = 'localhost';
  wbemFlagForwardOnly = $00000020;
var
  FSWbemLocator:  OLEVariant;
  FWMIService:    OLEVariant;
  FWbemObjectSet: OLEVariant;
  FWbemObject:    OLEVariant;
  oEnum:          IEnumvariant;
  iValue:         LongWord;
begin;
  CoInitialize(nil);

  Result.FreeSpace := 0;
  Result.Usage     := 0;
  FSWbemLocator    := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService      := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser, WbemPassword);
  FWbemObjectSet   := FWMIService.ExecQuery(Format('SELECT * FROM Win32_LogicalDisk Where Caption=%s', [QuotedStr('c')]), 'WQL', wbemFlagForwardOnly);
  oEnum            := IUnknown(FWbemObjectSet._NewEnum) as IEnumvariant;
  if oEnum.Next(1, FWbemObject, iValue) = 0 then
  begin
    Result.FreeSpace := FWbemObject.FreeSpace;
    Result.Usage     := FWbemObject.Size - Result.FreeSpace;
    FWbemObject      := Unassigned;
  end;
end;
{$ENDIF}

function MemoryUsed: NativeUInt; inline;
var
  MMS:   TMemoryManagerState;
  Block: TSmallBlockTypeState;
begin
  GetMemoryManagerState(MMS);
  Result := MMS.TotalAllocatedMediumBlockSize + MMS.TotalAllocatedLargeBlockSize;
  for Block in MMS.SmallBlockTypeStates do
    Result := Result + (Block.UseableBlockSize * Block.AllocatedBlockCount);
end;

type
  TProcessCpuUsage = record
  private
    class var FLastUsed, FLastTime: UInt64;
    class var FCpuCount:            Integer;
  public
    class function Current: Single; static;
  end;

class function TProcessCpuUsage.Current: Single;
var
  Usage, ACurTime:                            UInt64;
  CreateTime, ExitTime, UserTime, KernelTime: TFileTime;

  function FileTimeToI64(const ATime: TFileTime): Int64;
  begin
    Result := (Int64(ATime.dwHighDateTime) shl 32) + ATime.dwLowDateTime;
  end;

  function GetCPUCount: Integer;
  var
    SysInfo: TSystemInfo;
  begin
    GetSystemInfo(SysInfo);
    Result := SysInfo.dwNumberOfProcessors;
  end;

begin
  Result := 0;
  if GetProcessTimes(GetCurrentProcess, CreateTime, ExitTime, KernelTime, UserTime) then
  begin
    ACurTime := GetTickCount;
    Usage    := FileTimeToI64(UserTime) + FileTimeToI64(KernelTime);
    if FLastTime <> 0 then
      Result := (Usage - FLastUsed) / (ACurTime - FLastTime) / FCpuCount / 100
    else
      FCpuCount := GetCPUCount;
    FLastUsed   := Usage;
    FLastTime   := ACurTime;
  end;
end;

{ TBaseMetric }

constructor TBaseMetric.Create;
var
  memstatus: TMemoryStatusEx;
begin
  Memory_Workingset := TSample.Create(TMetricsetDefaults.MemoryUsage());
  Memory_Usage      := TSample.Create(MemoryUsed);

  memstatus.dwLength := SizeOf(memstatus);
  if GlobalMemoryStatusEx(memstatus) then
  begin
    System_Memory      := TSample.Create(memstatus.ullTotalPhys);
    System_Memory_Free := TSample.Create(memstatus.ullAvailPhys);
  end;

  System_CPU_Process := TSample.Create(TProcessCpuUsage.Current);
  System_CPU         := TSample.Create(TThread.GetCPUUsage(FSystemTimes) / 100);
end;

class constructor TBaseMetric.Create;
begin
  TThread.GetSystemTimes(FSystemTimes);
end;

destructor TBaseMetric.Destroy;
begin
  Memory_Workingset.Free;
  Memory_Usage.Free;
  System_Memory.Free;
  System_Memory_Free.Free;
  System_CPU_Process.Free;
  System_CPU.Free;
  inherited;
end;

end.

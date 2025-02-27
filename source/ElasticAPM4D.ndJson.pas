unit ElasticAPM4D.ndJson;

interface

uses
  System.classes, System.SysUtils, System.Generics.Collections,
  ElasticAPM4D.Metadata, ElasticAPM4D.Transaction, ElasticAPM4D.Span, ElasticAPM4D.Error, ElasticAPM4D.MetricSet;

type
  TndJson = class
  strict private
  const
    sNDJsonSeparator = sLineBreak;
  strict private
    FJson: Widestring;
  public
    procedure Add(ASpans: TList<TSpan>); overload;
    procedure Add(AMetadata: TMetadata); overload;
    procedure Add(ATransaction: TTransaction); overload;
    procedure Add(AErrors: TList<TError>); overload;
    procedure Add(AMetrics: TList<TBaseMetricSet>); overload;

    function Get: Widestring;
  end;

implementation

{ TndJson }

procedure TndJson.Add(AMetadata: TMetadata);
begin
  FJson := AMetadata.ToJsonString;
end;

procedure TndJson.Add(ASpans: TList<TSpan>);
var
  LSpan: TSpan;
begin
  if not Assigned(ASpans) then
    exit;
  for LSpan in ASpans.List do
  begin
    if LSpan <> nil then
      FJson := FJson + sNDJsonSeparator + LSpan.ToJsonString;
  end;
end;

procedure TndJson.Add(AErrors: TList<TError>);
var
  LError: TError;
begin
  if not Assigned(AErrors) then
    exit;
  for LError in AErrors.List do
    if LError <> nil then
      FJson := FJson + sNDJsonSeparator + LError.ToJsonString;
end;

procedure TndJson.Add(ATransaction: TTransaction);
begin
  FJson := FJson + sNDJsonSeparator + ATransaction.ToJsonString;
end;

function TndJson.Get: Widestring;
begin
  Result := FJson;
end;

procedure TndJson.Add(AMetrics: TList<TBaseMetricSet>);
var
  LMetric: TBaseMetricSet;
begin
  if not Assigned(AMetrics) then
    exit;
  for LMetric in AMetrics.List do
    if LMetric <> nil then
      FJson := FJson + sNDJsonSeparator + LMetric.ToJsonString;
end;

end.

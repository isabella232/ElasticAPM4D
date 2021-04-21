unit ElasticAPM4D.MetricSet;

interface

type
  TSample = class
  private
    Fvalue: Double;
  public
    constructor Create(const aValue: Double);

    property value: Double read Fvalue write Fvalue;
  end;

  TBaseMetricSet = class
  private
    Ftimestamp: Int64;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function ToJsonString: string;

    property Timestamp: Int64 read Ftimestamp write Ftimestamp;
  end;

  TBaseSampleSet = class
  end;

  // https://github.com/elastic/apm-server/blob/v7.12.0/docs/spec/v2/metricset.json
  TMetricSet<T: TBaseSampleSet, constructor> = class(TBaseMetricSet)
  private
    Fsamples: T;
  public
    constructor Create; override;
    destructor Destroy; override;

    property Samples: T read Fsamples write Fsamples;
  end;

implementation

uses
  System.SysUtils,
  Rest.Json,
  ElasticAPM4D.Utils,
  ElasticAPM4D.Resources;

{ TMetricSet<T> }

constructor TMetricSet<T>.Create;
begin
  inherited;
  Fsamples := T.Create;
end;

destructor TMetricSet<T>.Destroy;
begin
  Fsamples.Free;
  inherited;
end;

{ TBaseMetricSet }

constructor TBaseMetricSet.Create;
begin
  Ftimestamp := TTimestampEpoch.Get(now);
end;

destructor TBaseMetricSet.Destroy;
begin
  inherited;
end;

function TBaseMetricSet.ToJsonString: string;
begin
  TJson.ObjectToJsonString(self);

  result := format(smetricSetJsonId, [TJson.ObjectToJsonString(self)]);
end;

{ TSample }

constructor TSample.Create(const aValue: Double);
begin
  Fvalue := aValue;
end;

end.

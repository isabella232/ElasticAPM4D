unit ElasticAPM4D.Request;

interface

uses
  System.Generics.Collections,
  REST.Json.Types,
  System.Json.Serializers;

type
  TSocket = class
  private
    FEncrypted:      Boolean;
    FRemote_address: string;
  public
    property Encrypted:      Boolean read FEncrypted write FEncrypted;
    property Remote_address: string read FRemote_address write FRemote_address;
  end;

  TURL = class
  private
    FFull:     string;
    FHash:     string;
    FHostname: string;
    FPathname: string;
    FPort:     Integer;
    FProtocol: string;
    FRaw:      string;
    FSearch:   string;
  public
    property Full:     string read FFull write FFull;
    property Hash:     string read FHash write FHash;
    property Hostname: string read FHostname write FHostname;
    property Pathname: string read FPathname write FPathname;
    property Port:     Integer read FPort write FPort;
    property Protocol: string read FProtocol write FProtocol;
    property Raw:      string read FRaw write FRaw;
    property Search:   string read FSearch write FSearch;
  end;

  TKeyValues = class(TDictionary<string, string>);

  TRequest = class
  private
    FBody: string;
    [JSONMarshalledAttribute(False)]
    Fcookies: TKeyValues;
    [JSONMarshalledAttribute(False)]
    Fheaders:      TKeyValues;
    FHttp_version: string;
    FMethod:       string;
    FSocket:       TSocket;
    FUrl:          TURL;
    function GetHeaders: TKeyValues;
    function GetCookies: TKeyValues;
  public
    constructor Create;
    destructor Destroy; override;

    property Body: string read FBody write FBody;
    property Cookies: TKeyValues read GetCookies write Fcookies;

    property Headers: TKeyValues read GetHeaders write Fheaders;
    function HasHeaders(): Boolean;

    property Http_version: string read FHttp_version write FHttp_version;
    property Method: string read FMethod write FMethod;
    property Socket: TSocket read FSocket;
    property Url: TURL read FUrl;
  end;

implementation

uses
  System.SysUtils;

{ TRequest }

constructor TRequest.Create;
begin
  FSocket := TSocket.Create;
  FUrl    := TURL.Create;
end;

destructor TRequest.Destroy;
begin
  FUrl.Free;
  FSocket.Free;
    Fcookies.Free;
  Fheaders.Free;
  inherited;
end;

function TRequest.GetCookies: TKeyValues;
begin
  if Fcookies = nil then
    Fcookies := TKeyValues.Create();
  Result     := Fcookies;
end;

function TRequest.GetHeaders: TKeyValues;
begin
  if Fheaders = nil then
    Fheaders := TKeyValues.Create();
  Result     := Fheaders;
end;

function TRequest.HasHeaders: Boolean;
begin
  Result := (Fheaders <> nil) and (Fheaders.Count > 0);
end;

end.

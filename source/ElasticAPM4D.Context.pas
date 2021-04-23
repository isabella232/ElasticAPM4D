unit ElasticAPM4D.Context;

interface

uses
  Classes,
  System.SysUtils,
  System.Json,
  REST.Json.Types,
  ElasticAPM4D.User,
  ElasticAPM4D.Request,
  ElasticAPM4D.Service;

type
  TPage = class
  private
    FReferer: string;
    FUrl:     string;
  public
    property Referer: string read FReferer write FReferer;
    property Url:     string read FUrl write FUrl;
  end;

  TResponse = class
  private
    FFinished:     Boolean;
    FHeaders_sent: Boolean;
    FStatus_code:  Integer;
    [JSONMarshalledAttribute(False)]
    Fheaders: TKeyValues;
    function GetHeaders: TKeyValues;
  public
    property Finished:     Boolean read FFinished write FFinished;
    property Headers_sent: Boolean read FHeaders_sent write FHeaders_sent;
    property Status_code:  Integer read FStatus_code write FStatus_code;
    property Headers:      TKeyValues read GetHeaders write Fheaders;

    function HasHeaders(): Boolean;
  end;

  TContext = class
  private
    FPage:     TPage;
    FResponse: TResponse;
    FRequest:  TRequest;
    FUser:     TUser;
    [JSONMarshalledAttribute(False)]
    FTags: TKeyValues;
    function GetTags: TKeyValues;
    function GetRequest: TRequest;
    function GetPage: TPage;
    function GetResponse: TResponse;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property User: TUser read FUser write FUser;

    property Request: TRequest read GetRequest write FRequest;
    function HasRequestHeaders: Boolean;
    function HasResponseHeaders: Boolean;

    property Page: TPage read GetPage write FPage;
    property Response: TResponse read GetResponse write FResponse;

    property Tags: TKeyValues read GetTags;
    function HasTags: Boolean;
  end;

implementation

constructor TContext.Create;
begin
  FUser := TUser.Create;
end;

destructor TContext.Destroy;
begin
  FUser.Free;
  FPage.Free;
  FResponse.Free;
  FRequest.Free;
  FTags.Free;
  inherited;
end;

function TContext.GetPage: TPage;
begin
  if FPage = nil then
    FPage := TPage.Create;
  Result  := FPage;
end;

function TContext.GetRequest: TRequest;
begin
  if FRequest = nil then
    FRequest := TRequest.Create;
  Result     := FRequest;
end;

function TContext.GetResponse: TResponse;
begin
  if FResponse = nil then
    FResponse := TResponse.Create;
  Result      := FResponse;
end;

function TContext.GetTags: TKeyValues;
begin
  if FTags = nil then
    FTags := TKeyValues.Create;
  Result  := FTags;
end;

function TContext.HasRequestHeaders: Boolean;
begin
  Result := (FRequest <> nil) and FRequest.HasHeaders();
end;

function TContext.HasResponseHeaders: Boolean;
begin
  Result := (FResponse <> nil) and FResponse.HasHeaders();
end;

function TContext.HasTags: Boolean;
begin
  Result := (FTags <> nil) and (FTags.Count > 0);
end;

{ TResponse }

function TResponse.GetHeaders: TKeyValues;
begin
  if Fheaders = nil then
    Fheaders := TKeyValues.Create();
  Result     := Fheaders;
end;

function TResponse.HasHeaders: Boolean;
begin
  Result := (Fheaders <> nil) and (Fheaders.Count > 0);
end;

end.

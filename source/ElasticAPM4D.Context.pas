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
    Fheaders:      TObject;
  public
    property Finished:     Boolean read FFinished write FFinished;
    property Headers_sent: Boolean read FHeaders_sent write FHeaders_sent;
    property Status_code:  Integer read FStatus_code write FStatus_code;
    property Headers:      TObject read Fheaders write Fheaders;
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
  public
    constructor Create; virtual;
    destructor Destroy; override;

    property User: TUser read FUser write FUser;
    property Request: TRequest read FRequest write FRequest;
    property Page: TPage read FPage write FPage;
    property Response: TResponse read FResponse write FResponse;

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

function TContext.GetTags: TKeyValues;
begin
  if FTags = nil then
    FTags := TKeyValues.Create;
  Result  := FTags;
end;

function TContext.HasTags: Boolean;
begin
  Result := (FTags <> nil) and (FTags.Count > 0);
end;

end.

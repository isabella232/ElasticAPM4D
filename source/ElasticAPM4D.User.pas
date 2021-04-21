unit ElasticAPM4D.User;

interface

type
  TUser = class
  private
    FEmail:    string;
    FId:       string;
    FUsername: string;
  public
    property Id:       string read FId write FId;
    property Username: string read FUsername write FUsername;
    property Email:    string read FEmail write FEmail;
  end;

implementation

end.

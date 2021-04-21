unit ElasticAPM4D.Stacktrace;

interface

type
  TStacktrace = class
  private
    FAbs_path:      string;
    FColno:         integer;
    FContext_line:  string;
    FFilename:      string;
    FFunction:      string;
    FLibrary_frame: Boolean;
    FLineno:        integer;
    FModule:        string;
    FPost_context:  TArray<string>;
    FPre_context:   TArray<string>;
    Fvars:          TObject;
  public
    property abs_path: string read FAbs_path write FAbs_path;
    property colno:    integer read FColno write FColno;
    property context_line:  string read FContext_line write FContext_line;
    property filename:      string read FFilename write FFilename;
    property &function:     string read FFunction write FFunction;
    property library_frame: Boolean read FLibrary_frame write FLibrary_frame default false;
    property lineno:        integer read FLineno write FLineno;
    property module:        string read FModule write FModule;
    property post_context:  TArray<string> read FPost_context write FPost_context;
    property pre_context:   TArray<string> read FPre_context write FPre_context;
    property vars:          TObject read Fvars write Fvars;
  end;

implementation

end.

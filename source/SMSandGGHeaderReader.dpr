program SMSandGGHeaderReader;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'SMS/GG rom header reader';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

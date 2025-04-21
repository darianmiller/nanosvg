program ExampleUsage;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {ExampleForm},
  svg.api in '..\svg.api.pas',
  svg.render in '..\svg.render.pas',
  svg.provider.nano in '..\svg.provider.nano.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TExampleForm, ExampleForm);
  Application.Run;
end.

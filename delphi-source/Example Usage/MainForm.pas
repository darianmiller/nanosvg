unit MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls;

type

  TPanel = class(Vcl.ExtCtrls.TPanel)
  protected
    procedure Paint; override;
  end;

  TExampleForm = class(TForm)
    Image1:TImage;
    butLoadSVG:TButton;
    Panel1:TPanel;
    Image2:TImage;
    memLog:TMemo;
    Label1:TLabel;
    PaintBox1:TPaintBox;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    procedure butLoadSVGClick(Sender:TObject);
    procedure FormCreate(Sender:TObject);
    procedure PaintBox1Paint(Sender:TObject);
  private
    procedure MyLog(const Msg:string);
    procedure LoadExample;
  end;

var
  ExampleForm:TExampleForm;

implementation

uses
  svg.render;

{$R *.dfm}


procedure TExampleForm.FormCreate(Sender:TObject);
begin
  ReportMemoryLeaksOnShutdown := True;
  TRenderSVG.OnLog := MyLog;

  LoadExample;

  PaintBox1.Invalidate;
end;


procedure TExampleForm.butLoadSVGClick(Sender:TObject);
begin
  LoadExample;
end;


procedure TExampleForm.MyLog(const Msg:string);
begin
  memLog.Lines.Add(Msg);
end;


procedure TExampleForm.PaintBox1Paint(Sender:TObject);
begin
  TRenderSVG.GetFromFile('Example4.svg', PaintBox1.ClientWidth, PaintBox1.ClientHeight, PaintBox1.Canvas);
end;


procedure TExampleForm.LoadExample;
var
  svg:UTF8String;
begin
  TRenderSVG.DrawSVGFileToImage('Example1.svg', Image1); // Bitmap retrieved from cache on second call with same file/resource name and size
  svg := TUTF8Util.ReadFromFile('Example2.svg');
  TRenderSVG.DrawToBitmap(svg, Image2.Picture.Bitmap, Image2.Width, Image2.Height); // direct load from svg xml string
end;


procedure TPanel.Paint;
begin
  // note: Example also demonstrates that Nano does not currently provide text support (convert text to paths)
  TRenderSVG.GetFromFile('Example' + Tag.ToString + '.svg', self.ClientWidth, self.ClientHeight, Canvas);
end;


end.

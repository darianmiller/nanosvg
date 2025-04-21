object ExampleForm: TExampleForm
  Left = 0
  Top = 0
  Caption = 'NanoSVG DLL usage in Delphi'
  ClientHeight = 527
  ClientWidth = 852
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object Image1: TImage
    Left = 8
    Top = 16
    Width = 612
    Height = 129
  end
  object Image2: TImage
    Left = 634
    Top = 16
    Width = 203
    Height = 497
  end
  object Label1: TLabel
    Left = 176
    Top = 149
    Width = 280
    Height = 15
    Caption = 'SVG is automatically centered and not stretched to fit'
  end
  object PaintBox1: TPaintBox
    Left = 515
    Top = 151
    Width = 105
    Height = 83
    OnPaint = PaintBox1Paint
  end
  object butLoadSVG: TButton
    Left = 8
    Top = 169
    Width = 121
    Height = 25
    Caption = 'Load Example.svg'
    TabOrder = 0
    OnClick = butLoadSVGClick
  end
  object Panel1: TPanel
    Tag = 1
    Left = 144
    Top = 170
    Width = 32
    Height = 32
    BorderStyle = bsSingle
    Caption = 'Panel1'
    TabOrder = 1
  end
  object memLog: TMemo
    Left = 8
    Top = 240
    Width = 612
    Height = 273
    ScrollBars = ssVertical
    TabOrder = 2
    WantReturns = False
  end
  object Panel2: TPanel
    Tag = 2
    Left = 182
    Top = 170
    Width = 32
    Height = 32
    BorderStyle = bsSingle
    Caption = 'Panel2'
    TabOrder = 3
  end
  object Panel3: TPanel
    Tag = 3
    Left = 220
    Top = 170
    Width = 32
    Height = 32
    BorderStyle = bsSingle
    Caption = 'Panel3'
    TabOrder = 4
  end
  object Panel4: TPanel
    Tag = 4
    Left = 258
    Top = 170
    Width = 32
    Height = 32
    BorderStyle = bsSingle
    Caption = 'Panel4'
    TabOrder = 5
  end
end

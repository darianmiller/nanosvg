unit svg.api;

interface
uses
  Vcl.Graphics;

type

  // Strategy Interface
  ISVGRasterizer = interface
  ['{6C360A22-89EA-4F1F-AA34-D73EAB1855FF}']
    procedure Rasterize(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
  end;


implementation

// toconsider: plutosvg, lunasvg if additional features needed
// toreview: https://zarko-gajic.iz.hr/delphi-high-dpi-road-ensuring-your-ui-looks-correctly/

end.

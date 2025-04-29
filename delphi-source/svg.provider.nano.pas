unit svg.provider.nano;

interface
uses
  Vcl.Graphics,
  svg.api;

type

  // Concrete Strategy
  TNanoSVGRasterizer = class(TInterfacedObject, ISVGRasterizer)
  private
    class procedure LogIt(const Msg:string); inline;
  public
    { ISVGRasterizer }
    procedure Rasterize(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
    function GetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;
    function GetSizedToFit(const SVGText:UTF8String; const TargetWidth:Integer; const TargetHeight:Integer; out ImageWidth:Integer; out ImageHeight:Integer):integer;

    // directly callable and used to implement the interface
    class procedure RasterizeWithNano(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
    class function NanoGetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;
    class function NanoGetSizedToFit(const SVGText:UTF8String; const TargetWidth:Integer; const TargetHeight:Integer; out ImageWidth:Integer; out ImageHeight:Integer):integer;
  end;


implementation
uses
  System.SysUtils,
  System.Types,
  System.Math,
  svg.render;


{$REGION 'nanosvg.dll'}
const
  DLL_NAME = 'nanosvg32.dll';

function rasterize_svg_fit(svg:PAnsiChar; targetW, targetH:Single; out imgW, imgH:Integer; convertToBGRA:Integer):PByteArray; cdecl; external DLL_NAME name '_rasterize_svg_fit';
procedure free_image(ptr:PByteArray); cdecl; external DLL_NAME name '_free_image';

function get_svg_nativesize(svg:PAnsiChar; out imgW, imgH:Integer):integer; cdecl; external DLL_NAME name '_get_svg_nativesize';
function get_svg_fit_size(svg:PAnsiChar; targetW, targetH:Single; out imgW, imgH:Integer):integer; cdecl; external DLL_NAME name '_get_svg_fit_size';
{$ENDREGION}



// simply forwards to class procedures (which can be directly called)
procedure TNanoSVGRasterizer.Rasterize(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
begin
  RasterizeWithNano(SVGText, TargetBitmap, TargetWidth, TargetHeight, UseTransparentBackground, BackgroundColor);
end;
function TNanoSVGRasterizer.GetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;
begin
  Result := NanoGetNativeSize(SVGText, ImageWidth, ImageHeight);
end;

function TNanoSVGRasterizer.GetSizedToFit(const SVGText:UTF8String; const TargetWidth:Integer; const TargetHeight:Integer; out ImageWidth:Integer; out ImageHeight:Integer):integer;
begin
  Result := NanoGetSizedToFit(SVGText, TargetWidth, TargetHeight, ImageWidth, ImageHeight);
end;


class procedure TNanoSVGRasterizer.LogIt(const Msg:string);
begin
  TRenderSVG.LogIt(Msg);
end;


class procedure TNanoSVGRasterizer.RasterizeWithNano(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
var
  Buffer:PByteArray;
  W, H, Y:Integer;
  SrcRow, DstRow:PByte;
  dx, dy:Integer;
  RenderWidth, RenderHeight:Integer;
  NullTerminated:UTF8String;
begin
  LogIt(Format('Rasterizing via nano dll w:%d h:%d', [TargetWidth, TargetHeight]));
  NullTerminated := SVGText + #0;

  TargetBitmap.Assign(nil);
  Buffer := rasterize_svg_fit(PAnsiChar(NullTerminated), TargetWidth, TargetHeight, W, H, 1);
  if Buffer = nil then
  begin
    LogIt('Nano rasterizing failed');
    Exit;
  end;

  if (TargetWidth <= 0) or (TargetHeight <= 0) or (W <= 0) or (H <= 0) then
  begin
    LogIt(Format('Invalid image. TargetWidth: %d TargetHeight: %d SVGImageWidth: %d SVGImageHeigth %d', [TargetWidth, TargetHeight, W, H]));
    free_image(Buffer);
    Exit;
  end;

  try
    LogIt(Format('Creating bitmap with TargetWidth: %d TargetHeight: %d SVGImageWidth: %d SVGImageHeigth %d', [TargetWidth, TargetHeight, W, H]));
    TargetBitmap.PixelFormat := pf32bit;
    TargetBitmap.SetSize(TargetWidth, TargetHeight);
    TargetBitmap.HandleType := bmDIB;

    if UseTransparentBackground then
    begin
      LogIt('Using transparent background');
      TargetBitmap.AlphaFormat := afDefined;
      // Fill each scanline with transparent pixels
      for Y := 0 to TargetHeight - 1 do
        FillChar(TargetBitmap.ScanLine[Y]^, TargetWidth * 4, 0);
    end
    else
    begin
      LogIt(Format('Filling background color: %d', [Ord(BackgroundColor)]));
      TargetBitmap.Canvas.Brush.Color := BackgroundColor;
      TargetBitmap.Canvas.FillRect(Rect(0, 0, TargetWidth, TargetHeight));
    end;

    // Calculate center offset
    dx := Max((TargetWidth - W) div 2, 0);
    dy := Max((TargetHeight - H) div 2, 0);
    RenderWidth := Min(W, TargetWidth - dx);
    RenderHeight := Min(H, TargetHeight - dy);
    LogIt(Format('Rendering image w:%d h:%d', [RenderWidth, RenderHeight]));

    for Y := 0 to RenderHeight - 1 do
    begin
      SrcRow := PByte(Buffer) + (Y * W * 4);
      DstRow := PByte(TargetBitmap.ScanLine[Y + dy]) + (dx * 4);
      Move(SrcRow^, DstRow^, RenderWidth * 4);
    end;

  finally
    free_image(Buffer);
  end;
end;


class function TNanoSVGRasterizer.NanoGetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;
var
  NullTerminated:UTF8String;
begin
  LogIt('Extracting native SVG size');
  NullTerminated := SVGText + #0;
  Result := get_svg_nativesize(PAnsiChar(NullTerminated), ImageWidth, ImageHeight);
end;

class function TNanoSVGRasterizer.NanoGetSizedToFit(const SVGText:UTF8String; const TargetWidth:Integer; const TargetHeight:Integer; out ImageWidth:Integer; out ImageHeight:Integer):integer;
var
  NullTerminated:UTF8String;
begin
  LogIt(Format('Calculating target SVG size to proportionately fit w:%d h:%d', [TargetWidth, TargetHeight]));
  NullTerminated := SVGText + #0;
  Result := get_svg_fit_size(PAnsiChar(NullTerminated), TargetWidth, TargetHeight, ImageWidth, ImageHeight);
end;



initialization
  TRenderSVG.RegisterRasterizer(TNanoSVGRasterizer.Create);

finalization
  TRenderSVG.UnregisterRasterizer;

end.


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

    // directly callable and used to implement the interface
    class procedure RasterizeWithNano(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
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
{$ENDREGION}



procedure TNanoSVGRasterizer.Rasterize(const SVGText:UTF8String; const TargetBitmap:TBitmap; const TargetWidth:Integer; const TargetHeight:Integer; const UseTransparentBackground:Boolean = True; const BackgroundColor:TColor = clNone);
begin
  // simply forwards to class procedure (which can be directly called)
  RasterizeWithNano(SVGText, TargetBitmap, TargetWidth, TargetHeight, UseTransparentBackground, BackgroundColor);
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


initialization
  TRenderSVG.RegisterRasterizer(TNanoSVGRasterizer.Create);

finalization
  TRenderSVG.UnregisterRasterizer;

end.


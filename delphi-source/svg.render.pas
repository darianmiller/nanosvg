//todo: Test multi-threaded rendering (possibly serialize)
unit svg.render;

interface

uses
  System.SysUtils,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  System.Generics.Collections,
  svg.api;

type
  TRenderSVGLogProc = procedure(const Msg:string) of object;

  // TRenderSVG
  // Acts as the single entry point for SVG rendering:
  //   Delegates all draw requests to the registered ISVGRasterizer implementation
  //   Provides shared optional logging and caching
  //   Hides engine-specific details so client code never needs to change
  //   Allows swapping SVG engines by a single RegisterRasterizer call
  TRenderSVG = class
  private class var
    FCache:TObjectDictionary<string, TBitmap>;
    FRasterizer:ISVGRasterizer;
  public class var
    OnLog:TRenderSVGLogProc;
  public
    class constructor CreateClass;
    class destructor DestroyClass;

    // Service locator
    class procedure RegisterRasterizer(const ARasterizer:ISVGRasterizer);
    class procedure UnregisterRasterizer;
    class function HasRasterizer: Boolean; inline;

    // SVG drawing without cache
    class procedure DrawToCanvas(const SVGText:UTF8String; const Target:TCanvas; const Width, Height:Integer);
    class procedure DrawToBitmap(const SVGText:UTF8String; const Target:TBitmap; const Width, Height:Integer);

    // SVG drawing with Bitmap cached based on File/ResName for a given width/height
    class procedure GetFromFile(const FileName:string; Width, Height:Integer; const Target:TBitmap); overload;
    class procedure GetFromFile(const FileName:string; Width, Height:Integer; const Target:TCanvas); overload;
    class procedure GetFromResource(const ResName:string; Width, Height:Integer; const Target:TBitmap); overload;
    class procedure GetFromResource(const ResName:string; Width, Height:Integer; const Target:TCanvas); overload;
    class procedure ClearCache;

    // Utility method for that includes image scaling
    class procedure DrawSVGFileToImage(const FileName:string; const Target:TImage);

    class function GetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;


    // Optional utility debugging method
    class procedure LogIt(const Msg:string);
  end;


  TUTF8Util = class
  public
    class function ReadFromFile(const FileName:string):UTF8String;
    class function ReadFromResource(const ResName:string):UTF8String;
    class function FromBytes(const Source:TBytes; const CheckBOM:Boolean = False):UTF8String;
  end;

implementation

uses
  System.Classes,
  System.Types,
  System.IOUtils;

const
  DefaultMissingSVG:UTF8String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">' +
                                 '<rect width="100%" height="100%" fill="#eee"/>' +
                                 '<line x1="0" y1="0" x2="64" y2="64" stroke="red" stroke-width="4"/>' +
                                 '<line x1="64" y1="0" x2="0" y2="64" stroke="red" stroke-width="4"/>' +
                                 '</svg>';

type
  TSVGSource = (SvgFromFile, SvgFromResource);


  TSVGCacheKey = record
    UniqueID:string; // File path or resource name
    Source:TSVGSource;
    Width, Height:Integer;
    class function CreateKey(const UniqueID:string; Source:TSVGSource; Width, Height:Integer):TSVGCacheKey; static;
    function ToString:string;
  end;



class function TSVGCacheKey.CreateKey(const UniqueID:string; Source:TSVGSource; Width, Height:Integer):TSVGCacheKey;
begin
  Result := Default(TSVGCacheKey);
  Result.UniqueID := UniqueID;
  Result.Source := Source;
  Result.Width := Width;
  Result.Height := Height;
end;


function TSVGCacheKey.ToString:string;
const
  KindChars: array [TSVGSource] of Char = ('F', 'R');
begin
  Result := Format('%s@%dx%d:%s', [UniqueID, Width, Height, KindChars[Source]]);
end;


class function TUTF8Util.ReadFromResource(const ResName:string):UTF8String;
var
  RS:TResourceStream;
  Bytes:TBytes;
begin
  RS := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
  try
    SetLength(Bytes, RS.Size);
    RS.ReadBuffer(Bytes[0], RS.Size);
    Result := TUTF8Util.FromBytes(Bytes);
  finally
    RS.Free;
  end;
end;


class function TUTF8Util.ReadFromFile(const FileName:string):UTF8String;
begin
  Result := FromBytes(TFile.ReadAllBytes(FileName), { CheckBOM= } True);
end;


class function TUTF8Util.FromBytes(const Source:TBytes; const CheckBOM:Boolean = False):UTF8String;
var
  Count:Integer;
  Offset:Integer;
begin

  Offset := 0;
  Count := Length(Source);

  if CheckBOM then
  begin
    if (Length(Source) >= 3) and (Source[0] = $EF) and (Source[1] = $BB) and (Source[2] = $BF) then // exclude BOM
    begin
      Offset := 3;
      Dec(Count, Offset);
    end;
  end;

  if Count > 0 then
  begin
    SetString(Result, PAnsiChar(@Source[Offset]), Count)
  end
  else
  begin
    Result := '';
  end;

end;


class constructor TRenderSVG.CreateClass;
begin
  FCache := TObjectDictionary<string, TBitmap>.Create([doOwnsValues]);
end;


class destructor TRenderSVG.DestroyClass;
begin
  FCache.Free;
end;

class procedure TRenderSVG.RegisterRasterizer(const ARasterizer:ISVGRasterizer);
begin
  FRasterizer := ARasterizer;
end;

class procedure TRenderSVG.UnregisterRasterizer;
begin
  FRasterizer := nil;
end;

class function TRenderSVG.HasRasterizer:Boolean;
begin
  Result := Assigned(FRasterizer);
end;


class procedure TRenderSVG.LogIt(const Msg:string);
begin
  if Assigned(OnLog) then
    OnLog(Msg);
end;


class function TRenderSVG.GetNativeSize(const SVGText:UTF8String; out ImageWidth:Integer; out ImageHeight:Integer):integer;
begin
  if not HasRasterizer then
    raise Exception.Create('A SVG rasterizer has not yet been registered');

  Result := FRasterizer.GetNativeSize(SVGText, ImageWidth, ImageHeight);
end;

class procedure TRenderSVG.DrawSVGFileToImage(const FileName:string; const Target:TImage);
var
  dpi, ScaledWidth, ScaledHeight:Integer;
begin
  dpi := Target.CurrentPPI;
  if dpi = 96 then
  begin
    ScaledWidth := Target.Width;
    ScaledHeight := Target.Height;
  end
  else
  begin
    ScaledWidth := MulDivInt64(Target.Width, dpi, 96);
    ScaledHeight := MulDivInt64(Target.Height, dpi, 96);
    LogIt(Format('ScaledWidth %d ScaledHeight %d', [ScaledWidth, ScaledHeight]));
  end;

  TRenderSVG.GetFromFile(FileName, ScaledWidth, ScaledHeight, Target.Picture.Bitmap);
end;


class procedure TRenderSVG.GetFromFile(const FileName:string; Width, Height:Integer; const Target:TCanvas);
var
  TempBitmap:TBitmap;
begin
  TempBitmap := TBitmap.Create;
  try
    GetFromFile(FileName, Width, Height, TempBitmap);
    Target.Draw(0, 0, TempBitmap);
  finally
    TempBitmap.Free;
  end;
end;


class procedure TRenderSVG.GetFromResource(const ResName:string; Width, Height:Integer; const Target:TCanvas);
var
  TempBitmap:TBitmap;
begin
  TempBitmap := TBitmap.Create;
  try
    GetFromResource(ResName, Width, Height, TempBitmap);
    Target.Draw(0, 0, TempBitmap);
  finally
    TempBitmap.Free;
  end;
end;

class procedure TRenderSVG.GetFromFile(const FileName:string; Width, Height:Integer; const Target:TBitmap);
var
  Key:TSVGCacheKey;
  Cached:TBitmap;
  SVGText:UTF8String;
  Normalized:string;
begin
  LogIt(Format('GetFromFile %s w:%d h:%d', [FileName, Width, Height]));
  Normalized := TPath.GetFullPath(FileName);

  Key := TSVGCacheKey.CreateKey(Normalized, TSVGSource.SvgFromFile, Width, Height);
  if FCache.TryGetValue(Key.ToString, Cached) then
  begin
    Target.Assign(Cached);
    Exit;
  end;

  if FileExists(FileName) then
  begin
    SVGText := TUTF8Util.ReadFromFile(FileName);
  end
  else
  begin
    LogIt('DrawSVGFileToImage, file not found: ' + FileName);
    SVGText := DefaultMissingSVG;
  end;

  DrawToBitmap(SVGText, Target, Width, Height);
  Cached := TBitmap.Create;
  Cached.Assign(Target);
  FCache.Add(Key.ToString, Cached);
end;


class procedure TRenderSVG.GetFromResource(const ResName:string; Width, Height:Integer; const Target:TBitmap);
var
  Key:TSVGCacheKey;
  Cached:TBitmap;
  SVGText:UTF8String;
  Normalized:string;
begin
  LogIt(Format('GetFromResource %s w:%d h:%d', [ResName, Width, Height]));
  Normalized := ResName.ToUpper;

  Key := TSVGCacheKey.CreateKey(Normalized, TSVGSource.SvgFromResource, Width, Height);
  if FCache.TryGetValue(Key.ToString, Cached) then
  begin
    Target.Assign(Cached);
    Exit;
  end;
  SVGText := TUTF8Util.ReadFromResource(ResName);
  DrawToBitmap(SVGText, Target, Width, Height);

  Cached := TBitmap.Create;
  Cached.Assign(Target);
  FCache.Add(Key.ToString, Cached);
end;


class procedure TRenderSVG.ClearCache;
begin
  LogIt(Format('Clearing SVG Cache, count %d', [FCache.Count]));
  FCache.Clear;
end;


class procedure TRenderSVG.DrawToCanvas(const SVGText:UTF8String; const Target:TCanvas; const Width, Height:Integer);
var
  TempBitmap:TBitmap;
begin
  TempBitmap := TBitmap.Create;
  try
    // Current rasterize always centers and keeps aspect ratio intact
    DrawToBitmap(SVGText, TempBitmap, Width, Height);
    Target.Draw(0, 0, TempBitmap);
  finally
    TempBitmap.Free;
  end;
end;


class procedure TRenderSVG.DrawToBitmap(const SVGText:UTF8String; const Target:TBitmap; const Width, Height:Integer);
begin
  if not HasRasterizer then
    raise Exception.Create('A SVG rasterizer has not yet been registered');

  FRasterizer.Rasterize(SVGText, Target, Width, Height);
end;




end.

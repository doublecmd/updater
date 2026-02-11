unit ExtractUnit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SevenZip, Windows;

type

  { TProgressEvent }

  TProgressEvent = function(Progress: Int32): Boolean of object;

  { TInStream }

  TInStream = class(TInterfacedObject, IInStream)
  private
    FStream: TStream;
  public
    function Read(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
    function Seek(Offset: Int64; SeekOrigin: UInt32; NewPosition: PInt64): HResult; winapi;
  public
    constructor Create(AStream: TStream);
  end;

  { TSequentialOutStream }

  TSequentialOutStream = class(TInterfacedObject, ISequentialOutStream)
  private
    FStream: THandleStream;
  public
    constructor Create(const FileName: WideString);
    destructor Destroy; override;
    function Write(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
  end;

  { TArchiveOpenCallback }

  TArchiveOpenCallback = class(TInterfacedObject, IArchiveOpenCallback)
    function SetTotal(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
    function SetCompleted(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
  end;

  { TArchiveExtractCallback }

  TArchiveExtractCallback = class(TInterfacedObject, IArchiveExtractCallback)
  private
    FTotal: UInt64;
    FArchive: IInArchive;
    FOnProgress: TProgressEvent;
    FTargetDirectory: WideString;
  public
    function SetTotal(Total: UInt64): HResult; winapi;
    function SetCompleted(CompleteValue: PUInt64): HResult; winapi;
    function GetStream(Index: UInt32; out OutStream: ISequentialOutStream; AskExtractMode: Int32): HResult; winapi;
    function PrepareOperation(AskExtractMode: Int32): HResult; winapi;
    function SetOperationResult(OpRes: Int32): HResult; winapi;
  public
    constructor Create(Archive: IInArchive; const TargetDirectory: String; OnProgress: TProgressEvent);
  end;

procedure Extract(AStream: TStream; const TargetDirectory: String; OnProgress: TProgressEvent);

implementation

uses
  ActiveX;

procedure SevenZipCheck(Value: HResult);
begin
  if (Value <> S_OK) and (Value <> E_ABORT) then
    raise Exception.Create(SysErrorMessage(Value));
end;

function ReadProp(constref Archive: IInArchive; Index: UInt32;
                  PropID: UInt32; out AValue: Boolean): Boolean;
var
  Value: TPropVariant;
begin
  Value:= Default(TPropVariant);
  SevenZipCheck(Archive.GetProperty(Index, PropID, Value));
  case Value.vt of
    VT_EMPTY, VT_NULL:
      Result:= False;
    VT_BOOL:
      begin
        Result:= True;
        AValue:= Value.bool;
      end;
    else begin
      Result:= False;
    end;
  end;
end;

function ReadProp(constref Archive: IInArchive; Index: UInt32;
                  PropID: UInt32; out AValue: TFileTime): Boolean;
var
  Value: TPropVariant;
begin
  Value:= Default(TPropVariant);
  SevenZipCheck(Archive.GetProperty(Index, PropID, Value));
  case Value.vt of
    VT_EMPTY, VT_NULL:
      Result:= False;
    VT_FILETIME:
      begin
        Result:= True;
        AValue:= Value.filetime;
      end;
    else begin
      Result:= False;
    end;
  end;
end;

function ReadProp(constref Archive: IInArchive; Index: UInt32;
                  PropID: UInt32; out AValue: WideString): Boolean;
var
  PropSize: UInt32;
  Value: TPropVariant;
begin
  Value:= Default(TPropVariant);
  SevenZipCheck(Archive.GetProperty(Index, PropID, Value));
  case Value.vt of
    VT_EMPTY, VT_NULL:
      Result:= False;
    VT_LPSTR:
      begin
        Result:= True;
        AValue:= WideString(AnsiString(Value.pszVal));
      end;
    VT_LPWSTR:
      begin
        Result:= True;
        AValue:= WideString(PWideChar(Value.pwszVal));
      end;
    VT_BSTR:
      begin
        Result:= True;
        PropSize:= SysStringByteLen(Value.bstrVal);
        SetLength(AValue, PropSize div SizeOf(WideChar));
        Move(Value.bstrVal^, PWideChar(AValue)^, PropSize);
        SysFreeString(Value.bstrVal);
      end;
    else begin
      Result:= False;
    end;
  end;
end;

procedure Extract(AStream: TStream; const TargetDirectory: String; OnProgress: TProgressEvent);
var
  Res: HResult;
  InterfaceID: TGUID;
  LibraryName: String;
  Archive: IInArchive;
  InStream: IInStream;
  MaxCheckStartPosition: Int64;
  ExtractCallback: IArchiveExtractCallback;
  ArchiveOpenCallback: IArchiveOpenCallback;
begin
  InterfaceID:= SevenZip.IInArchive;

  Res:= SevenZip.CreateObject(@CLSID_Format_7z, @InterfaceID, Archive);
  if (Res <> S_OK) then raise Exception.Create(SysErrorMessage(Res));

  ArchiveOpenCallback:= TArchiveOpenCallback.Create;

  MaxCheckStartPosition:= (1 << 22);
  InStream:= TInStream.Create(AStream);
  Archive.Open(InStream, @MaxCheckStartPosition, ArchiveOpenCallback);

  ExtractCallback:= TArchiveExtractCallback.Create(Archive, TargetDirectory, OnProgress);

  LibraryName:= TargetDirectory + PathDelim + SevenZipLibraryName;

  SysUtils.DeleteFile(LibraryName + '.old');
  RenameFile(LibraryName, LibraryName + '.old');
  try
    SevenZipCheck(Archive.Extract(nil, $FFFFFFFF, 0, ExtractCallback));
  except
    SysUtils.DeleteFile(LibraryName);
    RenameFile(LibraryName + '.old', LibraryName);
    raise;
  end;
end;

{ TInStream }

function TInStream.Read(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
var
  ASize: Integer;
begin
  ASize:= FStream.Read(Data^, Integer(Size));
  if ASize = 0 then
    Result:= E_FAIL
  else begin
    Result:= S_OK;
    if Assigned(ProcessedSize) then ProcessedSize^:= ASize;
  end;
end;

function TInStream.Seek(Offset: Int64; SeekOrigin: UInt32; NewPosition: PInt64): HResult; winapi;
var
  NewPos: Int64;
begin
  Result:= S_OK;
  NewPos:= FStream.Seek(Offset, TSeekOrigin(SeekOrigin));
  if Assigned(NewPosition) then NewPosition^:= NewPos;
end;

constructor TInStream.Create(AStream: TStream);
begin
  FStream:= AStream;
end;

{ TSequentialOutStream }

constructor TSequentialOutStream.Create(const FileName: WideString);
begin
  FStream:= TFileStream.Create(UTF8Encode(FileName), fmCreate);
end;

destructor TSequentialOutStream.Destroy;
begin
  inherited Destroy;
  FStream.Free;
end;

function TSequentialOutStream.Write(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
var
  ASize: Integer;
begin
  ASize:= FStream.Write(Data^, Integer(Size));
  if ASize = 0 then
    Result:= E_FAIL
  else begin
    Result:= S_OK;
    if Assigned(ProcessedSize) then ProcessedSize^:= ASize;
  end;
end;

{ IArchiveOpenCallback }

function TArchiveOpenCallback.SetTotal(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
begin
  Result:= S_OK;
end;

function TArchiveOpenCallback.SetCompleted(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
begin
  Result:= S_OK;
end;

{ TArchiveExtractCallback }

function TArchiveExtractCallback.SetTotal(Total: UInt64): HResult; winapi;
begin
  FTotal:= Total;
  Result:= S_OK;
end;

function TArchiveExtractCallback.SetCompleted(CompleteValue: PUInt64): HResult; winapi;
begin
  if Assigned(FOnProgress) and Assigned(CompleteValue) then
  begin
    if (FTotal > 0) then
    begin
      if not FOnProgress(CompleteValue^ * 100 div FTotal) then
        Exit(E_ABORT);
    end;
  end;
  Result:= S_OK;
end;

function TArchiveExtractCallback.GetStream(Index: UInt32; out
  OutStream: ISequentialOutStream; AskExtractMode: Int32): HResult; winapi;
var
  FileTime: TFileTime;
  IsDirectory: Boolean;
  PackedName: WideString;
  FindData: TWin32FileAttributeData;
begin
  Result:= S_OK;
  OutStream:= nil;

  if not ReadProp(FArchive, Index, kpidPath, PackedName) then
    Exit(E_FAIL);

  if not ReadProp(FArchive, Index, kpidIsDir, IsDirectory) then
    Exit(E_FAIL);

  // Directory
  if (IsDirectory) then
  begin
    if not ForceDirectories(FTargetDirectory + PackedName) then
    begin
      Result:= E_FAIL;
    end;
    Exit;
  end;

  if ReadProp(FArchive, Index, kpidMTime, FileTime) then
  begin
    if GetFileAttributesExW(PWideChar(FTargetDirectory + PackedName), GetFileExInfoStandard, @FindData) then
    begin
      // Skip files with the same or earlier time
      if UInt64(FileTime) <= UInt64(FindData.ftLastWriteTime) then Exit;
    end;
  end;

  // File
  try
    OutStream:= TSequentialOutStream.Create(FTargetDirectory + PackedName);
  except
    Result:= E_FAIL;
  end;
end;

function TArchiveExtractCallback.PrepareOperation(AskExtractMode: Int32): HResult; winapi;
begin
  Result:= S_OK;
end;

function TArchiveExtractCallback.SetOperationResult(OpRes: Int32): HResult; winapi;
begin
  Result:= S_OK;
end;

constructor TArchiveExtractCallback.Create(Archive: IInArchive;
  const TargetDirectory: String; OnProgress: TProgressEvent);
begin
  inherited Create;
  FArchive:= Archive;
  FOnProgress:= OnProgress;
  FTargetDirectory:= IncludeTrailingBackslash(UTF8Decode(TargetDirectory));
end;

end.


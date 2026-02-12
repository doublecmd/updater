unit SevenZip;

{$mode delphi}

interface

uses
  ActiveX, Windows;

// Client7z.cpp
const
  CLSID_Format_7z: TGUID = '{23170F69-40C1-278A-1000-000110070000}';

// IStream.h
type
  ISequentialInStream = interface(IUnknown)
    ['{23170F69-40C1-278A-0000-000300010000}']
    function Read(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
  end;

  ISequentialOutStream = interface(IUnknown)
    ['{23170F69-40C1-278A-0000-000300020000}']
    function Write(Data: Pointer; Size: UInt32; ProcessedSize: PUInt32): HResult; winapi;
  end;

  IInStream = interface(ISequentialInStream)
    ['{23170F69-40C1-278A-0000-000300030000}']
    function Seek(Offset: Int64; SeekOrigin: UInt32; NewPosition: PInt64): HResult; winapi;
  end;

// PropID.h
const
  kpidPath = 3;
  kpidIsDir = 6;
  kpidMTime = 12;

// IProgress.h
type
  IProgress = interface(IUnknown)
    ['{23170F69-40C1-278A-0000-000000050000}']
    function SetTotal(Total: UInt64): HResult; winapi;
    function SetCompleted(CompleteValue: PUInt64): HResult; winapi;
  end;

// IArchive.h
const
  // Ask mode
  kExtract = 0;
  kTest = 1;
  kSkip = 2;

  // Operation result
  kOK = 0;

type
  IArchiveOpenCallback = interface(IUnknown)
    ['{23170F69-40C1-278A-0000-000600100000}']
    function SetTotal(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
    function SetCompleted(Files: PUInt64; Bytes: PUInt64): HResult; winapi;
  end;

  IArchiveExtractCallback = interface(IProgress)
    ['{23170F69-40C1-278A-0000-000600200000}']
    function GetStream(Index: UInt32; out OutStream: ISequentialOutStream; AskExtractMode: Int32): HResult; winapi;
    function PrepareOperation(AskExtractMode: Int32): HResult; winapi;
    function SetOperationResult(OpRes: Int32): HResult; winapi;
  end;

  IInArchive = interface(IUnknown)
    ['{23170F69-40C1-278A-0000-000600600000}']
    function Open(Stream: IInStream; MaxCheckStartPosition: PUInt64; OpenCallback: IArchiveOpenCallback): HResult; winapi;
    function Close: HResult; winapi;
    function GetNumberOfItems(NumItems: PUInt32): HResult; winapi;
    function GetProperty(Index: UInt32; PropID: TPropID; var Value: TPropVariant): HResult; winapi;
    function Extract(Indices: PUInt32; NumItems: UInt32; TestMode: Int32; ExtractCallback: IArchiveExtractCallback): HResult; winapi;
    function GetArchiveProperty(PropID: TPropID; out Value: TPropVariant): HResult; winapi;
    function GetNumberOfProperties(NumProps: PUInt32): HResult; winapi;
    function GetPropertyInfo(Index: UInt32; out Name: TBStr; out PropID: TPropID; out VarType: TVarType): HResult; winapi;
    function GetNumberOfArchiveProperties(NumProps: PUInt32): HResult; winapi;
    function GetArchivePropertyInfo(Index: UInt32; out Name: TBStr; out PropID: TPropID; out VarType: TVarType): HResult; winapi;
  end;

function CreateObject(ClsID: PGUID; IID: PGUID; out outObject): HResult; winapi;

const
  SevenZipLibraryName = '7z.' + SharedSuffix;

implementation

function CreateObject; external SevenZipLibraryName name 'CreateObject';

end.


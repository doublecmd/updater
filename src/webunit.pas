unit WebUnit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  TUpdateProgress = function(Progress: Integer): Boolean of object;

function WebGetData(const Url: String): String;
function DownloadFile(const Url: String; OnProgress: TUpdateProgress; AStream: TStream): Boolean;

implementation

uses
  Windows, WinINet;

function WebGetData(const Url: String): String;
var
  Buffer: String;
  NetHandle: HINTERNET;
  UrlHandle: HINTERNET;
  lpdwIndex: DWORD = 0;
  lpdwBufferLength: DWORD;
begin
  Result:= EmptyStr;
  NetHandle:= InternetOpenW('Double Commander', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(NetHandle) then
  try
    UrlHandle := InternetOpenUrlW(NetHandle, PWideChar(UTF8Decode(Url)), nil, 0, INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_NO_AUTO_REDIRECT, 0);
    if Assigned(UrlHandle) then
    try
      Buffer:= EmptyStr;
      SetLength(Buffer, 8192);
      lpdwBufferLength:= Length(Buffer);
      HttpQueryInfo(UrlHandle, HTTP_QUERY_LOCATION, @Buffer[1], lpdwBufferLength, lpdwIndex);
      Result:= Copy(Buffer, 1, lpdwBufferLength);
    finally
      InternetCloseHandle(UrlHandle);
    end;
  finally
    InternetCloseHandle(NetHandle);
  end;
end;

function DownloadFile(const Url: String; OnProgress: TUpdateProgress; AStream: TStream): Boolean;
var
  Buffer: String;
  APos, ASize: Int64;
  NetHandle: HINTERNET;
  UrlHandle: HINTERNET;
  BytesRead: DWORD = 0;
  lpdwIndex: DWORD = 0;
  lpdwBufferLength: DWORD;
begin
  Result:= False;
  NetHandle:= InternetOpenW('Double Commander', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);

  if Assigned(NetHandle) then
  begin
    UrlHandle:= InternetOpenUrlW(NetHandle, PWideChar(UTF8Decode(Url)), nil, 0, INTERNET_FLAG_RELOAD, 0);

    if Assigned(UrlHandle) then
    begin
      APos:= 0;
      Buffer:= EmptyStr;
      SetLength(Buffer, 32768);
      lpdwBufferLength:= Length(Buffer);
      HttpQueryInfo(UrlHandle, HTTP_QUERY_CONTENT_LENGTH, @Buffer[1], lpdwBufferLength, lpdwIndex);
      ASize:= StrToInt64Def(Copy(Buffer, 1, lpdwBufferLength), 0);
      Result:= (ASize > 0);
      if Result then
      repeat
        if InternetReadFile(UrlHandle, @Buffer[1], Length(Buffer), BytesRead) then
        begin
          if (BytesRead > 0) then
          begin
            Inc(APos, BytesRead);
            AStream.Write(Buffer[1], BytesRead);
            if not OnProgress(APos * 100 div ASize) then
              Break;
          end;
        end;
      until (BytesRead = 0);
      Result:= (APos = ASize);
      InternetCloseHandle(UrlHandle);
    end;
    InternetCloseHandle(NetHandle);
  end;
end;

end.


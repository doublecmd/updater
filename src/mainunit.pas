{
   Double Commander Updater
   ----------------------------------------------------------------------------
   Main window

   Copyright (C) 2026 Alexander Koblov (alexx2000@mail.ru)

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this program. If not, see <http://www.gnu.org/licenses/>.
}

unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  LCLType, IniFiles;

const
  TargetOS  = {$I %FPCTARGETOS%};
  TargetCPU = {$I %FPCTARGETCPU%};

const
  VERSION = '1.3.0';
  REVISION_URL = 'https://github.com/doublecmd/snapshots/releases/latest';
  CHANGELOG_URL = 'https://github.com/doublecmd/snapshots/releases/download/%s/changelog.txt';
  ARCHIVE_URL = 'https://github.com/doublecmd/snapshots/releases/download/%s/doublecmd-%s.r%s.%s-%s.7z';

type

  { TMainForm }

  TMainForm = class(TForm)
    btnCancel: TButton;
    lblOperation: TLabel;
    lblOperationValue: TLabel;
    lblComplete: TLabel;
    lblCompleteValue: TLabel;
    lblChangeLog: TLabel;
    memChangeLog: TMemo;
    pnlStatus: TPanel;
    procedure btnCancelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    Date: String;
    Value: String;
    Cancel: Boolean;
    Revision: String;
    Changelog: String;
    procedure ExecuteHandler;
    procedure Finalize(Data: PtrInt);
    procedure UpdateCaption(Data: PtrInt);
    procedure UpdateProgress(Data: PtrInt);
    procedure UpdateChangelog(Data: PtrInt);
    function UpdateState(AProgress: Integer): Boolean;
  protected
    FVersion: String;
    FDateOld: String;
    FConfirm: Boolean;
    FConfig: TMemIniFile;
    FOncePerDay: Boolean;
    FRevisionOld: String;
    procedure ExecuteCommander;
    procedure LoadConfiguration;
    procedure SaveConfiguration;
    function CheckUpdate: Boolean;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Process, WebUnit, ExtractUnit;

resourcestring
  rsNewSnapshot = 'New snapshot %s is available!';
  rsUpdateQuery = 'Do you want to update?';
  rsExtractLabel = 'Extracting';
  rsClose = 'Close';

function TMainForm.CheckUpdate: Boolean;
var
  Message: String;
begin
  Result:= False;
  Date:= FormatDateTime('yyyy-mm-dd', Now);

  if FOncePerDay and (FDateOld = Date) then Exit;
  Revision:= ExtractFileName(WebGetData(REVISION_URL));

  if FOncePerDay and (Length(Revision) > 0) then
  begin
    FConfig.WriteString('General', 'Date', Date);
  end;

  if (Length(Revision) > 0) and (Revision <> FRevisionOld) then
  begin
    if not FConfirm then Exit(True);
    Message:= Format(rsNewSnapshot, [Revision]) + LineEnding + LineEnding + rsUpdateQuery;
    Result:= (DefaultMessageBox(PAnsiChar(Message), 'Double Commander', MB_YESNO) = mrYes);
  end;
end;

procedure TMainForm.ExecuteCommander;
var
  Index: Integer;
  FileName: String;
begin
  FileName:= ExtractFileName(ParamStr(0));
  FileName:= StringReplace(FileName, 'updater', 'doublecmd', []);

  with TProcess.Create(Self) do
  begin
    Executable:= ExtractFilePath(ParamStr(0)) + FileName;

    for Index:= 1 to ParamCount do
    begin
      Parameters.Add(ParamStr(Index));
    end;
    Execute;
  end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  LoadConfiguration;

  if not CheckUpdate then
  begin
    ExecuteCommander;
    Application.Terminate;
  end
  else begin
    Caption:= Revision;
    TThread.ExecuteInThread(@ExecuteHandler);
    Visible:= True;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FConfig.Free;
end;

procedure TMainForm.btnCancelClick(Sender: TObject);
begin
  if (btnCancel.Tag > 0) then
    Application.Terminate
  else begin
    Cancel:= True;
    btnCancel.Enabled:= False;
  end;
end;

function TMainForm.UpdateState(AProgress: Integer): Boolean;
begin
  Result:= not Cancel;
  Application.QueueAsyncCall(@UpdateProgress, AProgress);
end;

procedure TMainForm.ExecuteHandler;
var
  ATemp: String;
  AStream: TStream;
  Result: PtrInt = 0;
begin
  AStream:= TStringStream.Create;
  try
    ATemp:= Format(CHANGELOG_URL, [Revision]);
    if DownloadFile(ATemp, @UpdateState, AStream) then
    begin
      Changelog:= TStringStream(AStream).DataString;
      Application.QueueAsyncCall(@UpdateChangelog, 0);
    end;
  finally
    FreeAndNil(AStream);
  end;

  ATemp:= Format(ARCHIVE_URL, [Revision, FVersion, Revision, TargetCPU, TargetOS]);

  Value:= ExtractFileName(ATemp);
  Application.QueueAsyncCall(@UpdateCaption, PtrInt(lblOperationValue));

  AStream:= TMemoryStream.Create;
  try
    if DownloadFile(ATemp, @UpdateState, AStream) then
    begin
      AStream.Position:= 0;
      Value:= rsExtractLabel;
      Application.QueueAsyncCall(@UpdateCaption, PtrInt(lblOperation));
      try
        Extract(AStream, ExtractFileDir(ParamStr(0)), @UpdateState);
        ExecuteCommander;
        SaveConfiguration;
      except
        on E: Exception do
        begin
          Result:= 1;
          Value:= E.Message;
          Application.QueueAsyncCall(@UpdateCaption, PtrInt(lblOperationValue));
        end;
      end;
    end;
  finally
    AStream.Free
  end;
  Application.QueueAsyncCall(@Finalize, Result);
end;

procedure TMainForm.Finalize(Data: PtrInt);
begin
  if Data = 0 then
    Application.Terminate
  else begin
    btnCancel.Tag:= Data;
    btnCancel.Caption:= rsClose;
  end;
end;

procedure TMainForm.UpdateCaption(Data: PtrInt);
var
  ALabel: TLabel absolute Data;
begin
  ALabel.Caption:= Value;
end;

procedure TMainForm.UpdateProgress(Data: PtrInt);
begin
  lblCompleteValue.Caption:= IntToStr(Data) + '%';
end;

procedure TMainForm.UpdateChangelog(Data: PtrInt);
begin
  memChangeLog.Text:= Changelog;
end;

procedure TMainForm.LoadConfiguration;
begin
  try
    FConfig:= TMemIniFile.Create('updater.ini');
    FConfirm:= FConfig.ReadBool('General', 'Confirm', True);
    FDateOld:= FConfig.ReadString('General', 'Date', EmptyStr);
    FVersion:= FConfig.ReadString('General', 'Version', VERSION);
    FOncePerDay:= FConfig.ReadBool('General', 'OncePerDay', False);
    FRevisionOld:= FConfig.ReadString('General', 'Revision', EmptyStr);
  except
    on E: Exception do MessageDlg(E.Message, mtError, [mbOK], 0, mbOK);
  end;
end;

procedure TMainForm.SaveConfiguration;
begin
  FConfig.WriteBool('General', 'Confirm', FConfirm);
  FConfig.WriteString('General', 'Version', FVersion);
  FConfig.WriteString('General', 'Revision', Revision);
  FConfig.WriteBool('General', 'OncePerDay', FOncePerDay);
end;

end.


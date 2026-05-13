{
   Double Commander
   -------------------------------------------------------------------------
   Load colors of files in file panels

   Copyright (C) 2024 Alexander Koblov (alexx2000@mail.ru)

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

}

unit uMasksExt;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs,
  uFile,           // TFile
  uFindFiles,      // TSearchTemplateRec
  uSearchTemplate, // TSearchTemplate
  uColorExt,       // TMaskItem for gColorExt
  uMasks,          // TMask
  RegExpr;

type

  TMaskWrap = class
  protected
    FTemplate: String;
    FUsePinyin: Boolean;
    FCaseSensitive: Boolean;
    FIgnoreAccents: Boolean;
    FWindowsInterpretation: Boolean;

    // extended with
    FNegateResult: Boolean;
    FMatchBeg, FMatchEnd: Boolean;

    procedure SetCaseSence(ACaseSence: Boolean); virtual;
    procedure SetTemplate(AValue: String); virtual;
    procedure SetNegateResult(AValue: Boolean);
    procedure SetMatchBeg(AValue: Boolean);
    procedure SetMatchEnd(AValue: Boolean);
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); virtual;
    function Matches(const AFile: TFile): Boolean; virtual; abstract;

    property Template:String read FTemplate write SetTemplate;
    property CaseSensitive:Boolean read FCaseSensitive write SetCaseSence;
    property NegateResult:Boolean read FNegateResult write SetNegateResult;
    property MatchBeg:Boolean read FMatchBeg write SetMatchBeg;
    property MatchEnd:Boolean read FMatchEnd write SetMatchEnd;
  end;

  // wrapper around TMask with match input TFile
  TMaskExtended = class(TMaskWrap)
  private
    FMask: TMask;
  protected
    procedure SetCaseSence(ACaseSence: Boolean); override;
    procedure SetTemplate(AValue: String); override;

    function PrepareFilter(const aFileFilter: String): String;
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); override;
    destructor Destroy; override;

    function Matches(const AFile: TFile): Boolean; override;
  end;

  // Adjacent / Consecutive character matching
  TMaskAdjacentChar = class(TMaskWrap)
  private
    function Srch(const AFileName: String): Boolean;
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); override;
    function Matches(const AFile: TFile): Boolean; override;
  end;

  TMaskTemplate = class(TMaskWrap)
  private
    procedure SetTemplateTo(const AValue: String);
  protected
    FSearchTemplate: TSearchTemplate;
    function CreateTempRecord(const AMaskStr: String; const AHideMatch, AIsRegExp: Boolean): TSearchTemplateRec;
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); override;
    destructor Destroy; override;
    function Matches(const AFile: TFile): Boolean; override;
  end;

  TMaskRegEx = class(TMaskWrap)
  private
    FRegExpr: TRegExpr;
    FIsInvalid: Boolean;
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); override;
    destructor Destroy; override;
    function Matches(const AFile: TFile): Boolean; override;
  end;

  TMaskLevenstein = class(TMaskWrap)
  private
    FAllowedDistance: Integer;
    function Distance(const AS1, AS2: String): Byte;
  public
    constructor Create(const AValue: String; const AOptions: TMaskOptions = []; const AMatchBeg: Boolean = False; const AMatchEnd: Boolean = False); override;
    function Matches(const AFile: TFile): Boolean; override;
  end;


  TMaskOperatorArray = array of Boolean;
  TParseStringListExtended = class(TStringList)
  public
    constructor Create(const AText, AOrSeparators: String; AAndSeparators: String; var AMaskOperatorArray: TMaskOperatorArray);
  end;

  TMaskListExtended = class
  private
    FMasks: TObjectList;
    FArrayItemsOr: TMaskOperatorArray;  // logical operator values in array: true for OR; False for AND
    function GetCount: Integer;
    function GetItem(Index: Integer): TMaskWrap;
  public
    constructor Create(
      const AValue: String;
      AOrSeparatorCharset: String = ';';
      AOptions: TMaskOptions = [];
      AAndSeparatorCharset: String = '&';
      const AMatchBeg: Boolean = False;
      const AMatchEnd: Boolean = False
    );
    destructor Destroy; override;
    function Matches(const AFile: TFile): Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMaskWrap read GetItem;
  end;

implementation

uses
  LazUTF8,
  DCConvertEncoding,
  uPinyin,
  uAccentsUtils,
  uGlobs,
  uRegExpr;


procedure TMaskWrap.SetCaseSence(ACaseSence: Boolean);
begin
  FCaseSensitive := ACaseSence;
end;

procedure TMaskWrap.SetTemplate(AValue: String);
begin
  FTemplate := AValue;
end;

procedure TMaskWrap.SetNegateResult(AValue: Boolean);
begin
  FNegateResult := AValue;
end;

procedure TMaskWrap.SetMatchBeg(AValue: Boolean);
begin
  FMatchBeg := AValue;
end;

procedure TMaskWrap.SetMatchEnd(AValue: Boolean);
begin
  FMatchEnd := AValue;
end;

constructor TMaskWrap.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
begin
  inherited Create;
  FUsePinyin := moPinyin in AOptions;
  FCaseSensitive := moCaseSensitive in AOptions;
  FIgnoreAccents := moIgnoreAccents in AOptions;
  FWindowsInterpretation := moWindowsMask in AOptions;
  FNegateResult := False;
  FMatchBeg := AMatchBeg;
  FMatchEnd := AMatchEnd;
end;


constructor TMaskExtended.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
var
  sModFilter: String;
begin
  inherited Create(AValue, AOptions, AMatchBeg, AMatchEnd);
  sModFilter := PrepareFilter(AValue);
  FMask := TMask.Create(sModFilter);
end;

function TMaskExtended.PrepareFilter(const aFileFilter: String): String;
var
  Index: Integer;
  sFileExt: String;
  sFilterNameNoExt: String;
begin
  Result := aFileFilter;
  if Result <> EmptyStr then
  begin
    Index:= Pos('.', Result);
    if (Index > 0) and ((Index > 1) or FirstDotAtFileNameStartIsExtension) then
      begin
        sFileExt := ExtractFileExt(Result);
        // replaced ExtractOnlyFileName with ChangeFileExt (Standard SysUtils function) TODO verify compatibility
        sFilterNameNoExt := ChangeFileExt(Result, '');
        if not (FMatchBeg) then
          sFilterNameNoExt := '*' + sFilterNameNoExt;
        if not (FMatchEnd) then
          sFilterNameNoExt := sFilterNameNoExt + '*';
        Result := sFilterNameNoExt + sFileExt + '*';
      end
    else
      begin
        if not (FMatchBeg) then
          Result := '*' + Result;
        Result := Result + '*';
      end;
  end;
end;

destructor TMaskExtended.Destroy;
begin
  FMask.Free;
  inherited Destroy;
end;

function TMaskExtended.Matches(const AFile: TFile): Boolean;
begin
  Result := FMask.Matches(AFile.Name);
  if FNegateResult then
    Result := not Result;
end;

procedure TMaskExtended.SetCaseSence(ACaseSence: Boolean);
begin
  FMask.CaseSensitive := ACaseSence;
  FCaseSensitive := ACaseSence;
end;

procedure TMaskExtended.SetTemplate(AValue: String);
begin
  FMask.Template := AValue;
  FTemplate := AValue;
end;



constructor TMaskAdjacentChar.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
begin
  inherited Create(AValue, AOptions, AMatchBeg, AMatchEnd);

  FTemplate := AValue;
  if FIgnoreAccents then
    FTemplate := NormalizeAccentedChar(FTemplate);
  if not FCaseSensitive then
    FTemplate := UTF8LowerCase(FTemplate);
end;

function TMaskAdjacentChar.Srch(const AFileName: String): Boolean;
var
  I, J, K, L : Integer;
  S: UnicodeString;
begin
  S := CeUtf8ToUtf16(AFileName);
  L := Length(S);
  K := Length(FTemplate) + 1;

  if (K = 1) then
  begin
    Result := True;
    Exit;
  end;

  if (L = 0) then
  begin
    Result := False;
    Exit;
  end;

  I := 1;
  for J := 1 To L do
  begin
    if (FTemplate[I] = S[J]) then
      I := I + 1;
    if (I = K) then
    begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function TMaskAdjacentChar.Matches(const AFile: TFile): Boolean;
var
  // Consecutive character matching search
  // Example: "abcd" is same as default doublecmd search "a*b*c*d"
  // (no extra * typing) and it matches for example a_best_cedr
  AFileName: String;
  ALT, ALF: Integer;
begin
  AFileName := AFile.Name;
  if FIgnoreAccents then
    AFileName := NormalizeAccentedChar(AFileName);
  if not FCaseSensitive then
    AFileName := UTF8LowerCase(AFileName);

  ALT := Length(FTemplate);
  ALF := Length(AFileName);

  if (
    (ALT > 0) and (ALF > 0) and
    (not FMatchEnd or (FMatchEnd and (FTemplate[ALT] = AFileName[ALF]))) and
    (not FMatchBeg or (FMatchBeg and (FTemplate[1] = AFileName[1])))
  ) then
    Result := Srch(AFileName)
  else
    Result := False;

  if FNegateResult then
    Result := not Result;
end;



constructor TMaskTemplate.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
begin
  FTemplate := AValue;
  if FIgnoreAccents then
    FTemplate := NormalizeAccentedChar(FTemplate);
  if not FCaseSensitive then
    FTemplate := UTF8LowerCase(FTemplate);

  SetTemplateTo(FTemplate);
end;

function TMaskTemplate.Matches(const AFile: TFile): Boolean;
begin

  try
    begin
      if Assigned(FSearchTemplate) and FSearchTemplate.CheckFile(AFile) then
        Result := True
      else
        Result := False;
    end;

  except
    on E: Exception do
    begin
      // WriteLn('TMaskTemplateError: ', E.Message);
      Result := True;
    end;
  end;

end;

function TMaskTemplate.CreateTempRecord(const AMaskStr: String; const AHideMatch, AIsRegExp: Boolean): TSearchTemplateRec;
var
  ASearchRecord: TSearchTemplateRec;
begin
  with ASearchRecord do
  begin

    if AHideMatch then
    begin
      FilesMasks :=         '';
      ExcludeFiles :=       AMaskStr;
    end
    else
    begin
      FilesMasks :=         AMaskStr;
      ExcludeFiles :=       '';
    end;

    ExcludeDirectories :=   '';
    StartPath :=            '';
    RegExp :=               AIsRegExp;
    IsPartialNameSearch :=  False; // ?allow for regular masks??::
    // Get template instead color mask. >msk_template    *.txt;*.mkv|FALSE|TRUE|FALSE|FALSE|
    FollowSymLinks :=       False;
    FindInArchives :=       False;
    SearchDepth :=          -1;
    AttributesPattern :=    '';

    IsDateFrom :=           False;
    IsDateTo :=             False;
    IsTimeFrom :=           False;
    IsTimeTo :=             False;
    IsNotOlderThan :=       False;
    IsFileSizeFrom :=       False;
    IsFileSizeTo :=         False;

    FileSizeUnit :=         TFileSizeUnit(0);

    IsFindText :=           False;
    IsReplaceText :=        False;
    HexValue :=             False;
    CaseSensitive :=        False;
    NotContainingText :=    False;
    TextRegExp :=           False;
    OfficeXML :=            False;
    TextEncoding :=         'Default';
    // if TextEncoding = 'UTF-8BOM' then TextEncoding := 'UTF-8';
    // if TextEncoding = 'UCS-2LE' then TextEncoding := 'UTF-16LE';
    // if TextEncoding = 'UCS-2BE' then TextEncoding := 'UTF-16BE';
    Duplicates :=            False;
    SearchPlugin :=          '';
    ContentPlugin :=         False;
  end;
  Result := ASearchRecord;

end;

procedure TMaskTemplate.SetTemplateTo(const AValue: String);
var
  ATemplateName: String;
  I: Integer;
  ATemplate: TSearchTemplate;
begin
  ATemplateName := AValue;

  // use mask from gColorExt as template
  for I := 0 to gColorExt.Count - 1 do
  begin

    if SameText(TMaskItem(gColorExt[I]).sName, AValue) then
    begin
      if IsMaskSearchTemplate(TMaskItem(gColorExt[I]).sExt) then
      begin
        // reference to existing Template
        ATemplateName := TMaskItem(gColorExt[I]).sExt;
        Break;
      end

      else
      begin
        // create new temporary template with given mask
        if (FSearchTemplate = nil) then
        begin
          FSearchTemplate := TSearchTemplate.Create;
        end;
        FSearchTemplate.TemplateName := AValue;
        FSearchTemplate.SearchRecord := CreateTempRecord(TMaskItem(gColorExt[I]).sExt, False, False);
        Exit;
      end;

    end;

  end;

  // use template from TemplateList
  ATemplate := gSearchTemplateList.TemplateByName[PAnsiChar(ATemplateName)];
  if (ATemplate = nil) then
    FreeAndNil(FSearchTemplate)
  else
  begin
    if (FSearchTemplate = nil) then
    begin
      FSearchTemplate := TSearchTemplate.Create;
    end;
    FSearchTemplate.SearchRecord := ATemplate.SearchRecord;
  end;

end;

destructor TMaskTemplate.Destroy;
begin
  FSearchTemplate.Free;
  inherited Destroy;
end;



constructor TMaskRegEx.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
var
  LValue: String;
begin
  inherited Create(AValue, AOptions, AMatchBeg, AMatchEnd);
  FTemplate := AValue;

  LValue := AValue;

  FRegExpr := TRegExpr.Create;
  try
    FRegExpr.ModifierI := not FCaseSensitive; // or: LValue := '(?i)' + LValue;

    if FMatchBeg and ((Length(LValue) > 0) and (LValue[1] <> '^')) then
      LValue := '^' + LValue;
    if FMatchEnd and ((Length(LValue) > 0) and (LValue[Length(LValue)] <> '$')) then
      LValue := LValue + '$';

    FRegExpr.Expression := LValue;
    FIsInvalid := False;
  except
    FIsInvalid := True;
  end;
end;

destructor TMaskRegEx.Destroy;
begin
  FRegExpr.Free;
  inherited Destroy;
end;

function TMaskRegEx.Matches(const AFile: TFile): Boolean;
var
  LFileName: String;
begin
  Result := True;
  if not Assigned(FRegExpr) or FIsInvalid then
    Exit; // expression syntax error

  LFileName := AFile.Name;

  // if FUsePinyin then
  //   LFileName := ChineseToPinyin(LFileName);
  if FIgnoreAccents then
    LFileName := NormalizeAccentedChar(LFileName);
  if not FCaseSensitive then
    LFileName := UTF8LowerCase(LFileName);

  try
    Result := FRegExpr.Exec(LFileName);
  except
    Result := True; // execution failure
  end;
end;



constructor TMaskLevenstein.Create(const AValue: String; const AOptions: TMaskOptions; const AMatchBeg: Boolean; const AMatchEnd: Boolean);
begin
  inherited Create(AValue, AOptions, AMatchBeg, AMatchEnd);
  FTemplate := AValue;
  if FIgnoreAccents then
    FTemplate := NormalizeAccentedChar(FTemplate);
  if not FCaseSensitive then
    FTemplate := UTF8LowerCase(FTemplate);

  if (Length(FTemplate) >= 2) and (FTemplate[1] in ['0'..'9']) then
  begin
    FAllowedDistance := StrToInt(FTemplate[1]);
    FTemplate := RightStr(FTemplate, Length(FTemplate)-1);
  end
  else
  begin
    FAllowedDistance := 1;
  end;

end;

function TMaskLevenstein.Distance(const AS1, AS2: String): Byte;
var
  ACharS1, ACharS2: Char;
  ALengthS1, ALengthS2, I, J, ACostCurrent, ACostLeft, ACostAbove: Integer;
  AArr: array of Integer;
begin
  ALengthS1 := Length(AS1);
  ALengthS2 := Length(AS2);

  if ALengthS1 > ALengthS2 then
  begin
    Result := Distance(AS2, AS1);
    Exit;
  end;

  if (ALengthS1 = 0) then
  begin
    Result := ALengthS2;
    Exit;
  end;

  if (AS1 = AS2) then
  begin
    Result := 0;
    Exit;
  end;

  SetLength(AArr, ALengthS2 + 1);
  for I := 1 to ALengthS2 do
  begin
    AArr[I] := I;
  end;

  ACharS1 := AS1[1];
  ACostCurrent := 0;
  for I := 1 to ALengthS1 do
  begin
    ACharS1 := AS1[I];
    ACostLeft := I-1;
    ACostCurrent := I;

    for J := 1 to ALengthS2 do
    begin
      ACostAbove := ACostCurrent;
      ACostCurrent := ACostLeft;
      ACostLeft := AArr[J];
      ACharS2 := AS2[J];

      if not (ACharS1 = ACharS2) then
      begin
        if (ACostLeft < ACostCurrent) then
          ACostCurrent := ACostLeft;  // insertion
        if (ACostAbove < ACostCurrent) then
          ACostCurrent := ACostAbove; // deletion
        ACostCurrent := ACostCurrent + 1;
      end;
      AArr[J] := ACostCurrent;
    end;
  end;

  SetLength(AArr, 0);
  Result := ACostCurrent;
end;

function TMaskLevenstein.Matches(const AFile: TFile): Boolean;
var
  AFileName: String;
  ADistance: Byte;
  ALen: Integer;
  ALengthTemplate: Integer;
  ALengthFileName: Integer;
begin
  AFileName := AFile.Name;
  if FIgnoreAccents then
    AFileName := NormalizeAccentedChar(AFileName);
  if not FCaseSensitive then
    AFileName := UTF8LowerCase(AFileName);

  ALengthTemplate := Length(FTemplate);
  ALengthFileName := Length(AFileName);

  if FMatchBeg and FMatchEnd then
    ADistance := Distance(AFileName, FTemplate)

  else if FMatchBeg then
  begin
    ALen := ALengthTemplate + FAllowedDistance;
    ADistance := Distance(Copy(AFileName, 1, ALen), FTemplate);
  end

  else if FMatchEnd then
  begin
    ALen := ALengthTemplate + FAllowedDistance;
    if ALen < ALengthFileName then
      ADistance := Distance(Copy(AFileName, ALengthFileName-ALen+1, ALengthFileName), FTemplate)
    else
      ADistance := Distance(AFileName, FTemplate);
  end

  else
    ADistance := Distance(AFileName, FTemplate) - Abs(ALengthFileName - ALengthTemplate);

  Result := ADistance <= FAllowedDistance;
  if FNegateResult then
    Result := not Result;
end;



constructor TParseStringListExtended.Create(const AText, AOrSeparators: String; AAndSeparators: String; var AMaskOperatorArray: TMaskOperatorArray);
var
  I, S, O: Integer;
begin
  inherited Create;
  O := 0;
  S := 1;
  SetLength(AMaskOperatorArray, 1);
  for I := 1 to Length(AText) do
  begin

    if Pos(AText[I], AOrSeparators) > 0 then
      AMaskOperatorArray[O] := True
    else if Pos(AText[I], AAndSeparators) > 0 then
      AMaskOperatorArray[O] := False
    else
      Continue;

    if I > S then
    begin
      O := O + 1;
      SetLength(AMaskOperatorArray, O+1);
      Add(Copy(AText, S, I - S));
    end;

    S := I + 1;
  end;

  if Length(AText) >= S then
  begin
    O := O + 1;
    Add(Copy(AText, S, Length(AText) - S + 1));
  end;

  AMaskOperatorArray[O-1] := True; // ignore & at the end
end;

constructor TMaskListExtended.Create(
  const AValue: String;
  AOrSeparatorCharset: String;
  AOptions: TMaskOptions;
  AAndSeparatorCharset: String;
  const AMatchBeg: Boolean;
  const AMatchEnd: Boolean);
var
  S: TParseStringListExtended;
  AMaskOperatorArray: TMaskOperatorArray;
  I: Integer;
  AMaskStr: String;
  AActivationChar: String;
  AMaskObj: TMaskWrap;
begin
  FMasks := TObjectList.Create(True);
  if AValue = '' then exit;

  S := TParseStringListExtended.Create(AValue, AOrSeparatorCharset, AAndSeparatorCharset, AMaskOperatorArray);
  FArrayItemsOr := AMaskOperatorArray;

  try
    for I := 0 to S.Count - 1 do
    begin
      AActivationChar := S[I][1];

      // TODO future plans: allow user to define custom AActivationChar instead: \/<>#!
      if (Pos(AActivationChar, '\/<>#!') > 0) and (Length(S[I]) = 1) then
      begin
        // only activation character - needed to keep track for AND operators functionality
        FMasks.Add(TMaskExtended.Create('*', AOptions, AMatchBeg, AMatchEnd));
        Continue;
      end
      else
        AMaskStr := RightStr(S[I], Length(S[I])-1); // cut off activation character

      case AActivationChar of
        '#': FMasks.Add(TMaskExtended.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd));
        '!':
          begin
            AMaskObj := TMaskExtended.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd);
            AMaskObj.NegateResult := True; // only for this filter
            FMasks.Add(AMaskObj);
          end;
        '/': FMasks.Add(TMaskAdjacentChar.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd));
        '\': FMasks.Add(TMaskRegEx.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd));
        '<': FMasks.Add(TMaskLevenstein.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd));
        '>': FMasks.Add(TMaskTemplate.Create(AMaskStr, AOptions, AMatchBeg, AMatchEnd));
        else
          FMasks.Add(TMaskExtended.Create(S[I], AOptions, AMatchBeg, AMatchEnd));
      end;

    end;
  finally
    S.Free;
  end;
end;

destructor TMaskListExtended.Destroy;
begin
  FMasks.Free;
  inherited Destroy;
end;

function TMaskListExtended.Matches(const AFile: TFile): Boolean;
var
  ABolOverallResult: Boolean;
  I: Integer;
begin
  Result := False;
  ABolOverallResult := True;

  for I := 0 to FMasks.Count - 1 do
  begin
    // if ABolOverallResult is False --> no need to check connected masks - the result will be False anyway...
    if ABolOverallResult and TMaskWrap(FMasks.Items[I]).Matches(AFile) then
    begin
      if FArrayItemsOr[I] then
      begin
        Result := ABolOverallResult;
        Break;
      end;
    end

    else
    begin
      if FArrayItemsOr[I] then
        ABolOverallResult := True   // OR operator -> reset
      else
        ABolOverallResult := False; // if one of contions is False then result is False (all conditions must be true for result to be true)
    end;

  end;
end;

function TMaskListExtended.GetItem(Index: Integer): TMaskWrap;
begin
  Result := TMaskWrap(FMasks.Items[Index]);
end;

function TMaskListExtended.GetCount: Integer;
begin
  Result := FMasks.Count;
end;

end.
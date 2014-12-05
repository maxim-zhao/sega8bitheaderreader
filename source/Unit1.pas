// SMS/GG rom header reader
// by Maxim
//
// This program reads in and works with the header found in all SMS/GG files
// and also the new SDSC header data.
// It also checks the checksum and tries to interpret the Sega header data.
// It displays all information in human-readable form, fetching strings
// from the offsets given in the SDSC header and splitting nibbles in the Sega
// header.
//
// Any questions to maxim@mwos.cjb.net

unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  ComCtrls, ShellAPI, INIFiles, StdCtrls, ExtCtrls, ImgList;

type
  TSDSCHeader=packed record // SDSC header and Sega header in one
    SDSCChars:array[0..3] of char;
    MajorVersion,MinorVersion,ReleaseDay,ReleaseMonth:byte;
    ReleaseYear,AuthorOffset,TitleOffset,ReleaseNotesOffset:word;
  end;
  TSegaHeader=packed record
    TMRSEGAChars:array[0..7] of char;
    UnknownValue,Checksum,PartNumber:word;
    Version,RegionAndCartSize:byte;
  end;
  TCodemastersHeader=packed record
    NumPages,Day,Month,Year,Hour,Minute:byte;
    Checksum,InverseChecksum:word;
    Reserved:array[0..5] of byte;
  end;

  TForm1 = class(TForm)
    TreeView1: TTreeView;
    ImageList1: TImageList;
    Memo1: TMemo;
    Splitter1: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
  private
    { Private declarations }
    procedure WMDROPFILES(var Message: TWMDROPFILES); message WM_DROPFILES;
    procedure LoadFile(filename:string);
    procedure DisplayFileInfo(f:TFileStream;filename:string);
    procedure DisplaySDSCHeader(f:TFileStream);
    function DisplaySegaHeader(f:TFileStream;offset:integer;force:boolean):boolean;
    procedure DisplayCodemastersHeader(f:TFileStream);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

// This function calculates the SMS internal checksum. The parameters should be obvious.
function CalcChecksum(var f:TFileStream;RangeStart, RangeEnd:longint; StartValue: word):word;
type
  FBufferArray = array [0..32768-1] of Byte;
var
  Buffer: ^FBufferArray; // This is the only way to get any-size buffers. 32KB is plenty.
  BytesRead, Count:integer;
  TotalRead:Longint;
begin
  Buffer:=AllocMem(Sizeof(Buffer^)); // allocate buffer

  f.Seek(RangeStart,soFromBeginning); // seek to start point
  TotalRead:=rangestart;
  Result:=startvalue;
  repeat // repeatedly read 32K chunks and checksum them, stopping at end point
    BytesRead:=f.Read(Buffer^,sizeof(Buffer^));
    if BytesRead>0 then for Count:=0 to BytesRead-1 do begin
      if TotalRead+Count-1=RangeEnd then break;
      Result:=Result+Buffer^[Count];
    end;
    Inc(TotalRead,BytesRead);
  until (BytesRead=0) or (TotalRead>=RangeEnd);
  FreeMem(Buffer, Sizeof(Buffer^));  // deallocate buffer
end;

function CalcCodiesChecksum(f:TFileStream;NumPages:byte):word;
type
  FBufferArray = array [0..8191] of Word;
var
  Buffer: ^FBufferArray;
  Count,WordsRead:integer;
  TotalRead:Longint;
begin
  Buffer:=AllocMem(Sizeof(Buffer^)); // allocate buffer

  f.Seek(0,soFromBeginning); // seek to start
  TotalRead:=0;
  Result:=0;
  repeat
    WordsRead:=f.Read(Buffer^,sizeof(Buffer^)) div 2;
    if WordsRead>0 then for Count:=0 to WordsRead-1 do begin
      if (TotalRead+Count<$3ff8) // these correspond to the words of the Sega header
      or (TotalRead+Count>$3fff) // at $7ff0-$7fff
      then Result:=Result+Buffer^[Count];
      if (TotalRead+Count=NumPages*$2000) then break;
    end;
    Inc(TotalRead,WordsRead);
  until (WordsRead=NumPages*$2000) or (WordsRead=0);
  FreeMem(Buffer, Sizeof(Buffer^));  // deallocate buffer
end;

function CRCFile(f:TFileStream): string;
const
  BufferSize=8192;
  CRC32Table: array[0..255] of dword =(
    $000000000, $077073096, $0ee0e612c, $0990951ba, $0076dc419, $0706af48f,
    $0e963a535, $09e6495a3, $00edb8832, $079dcb8a4, $0e0d5e91e, $097d2d988,
    $009b64c2b, $07eb17cbd, $0e7b82d07, $090bf1d91, $01db71064, $06ab020f2,
    $0f3b97148, $084be41de, $01adad47d, $06ddde4eb, $0f4d4b551, $083d385c7,
    $0136c9856, $0646ba8c0, $0fd62f97a, $08a65c9ec, $014015c4f, $063066cd9,
    $0fa0f3d63, $08d080df5, $03b6e20c8, $04c69105e, $0d56041e4, $0a2677172,
    $03c03e4d1, $04b04d447, $0d20d85fd, $0a50ab56b, $035b5a8fa, $042b2986c,
    $0dbbbc9d6, $0acbcf940, $032d86ce3, $045df5c75, $0dcd60dcf, $0abd13d59,
    $026d930ac, $051de003a, $0c8d75180, $0bfd06116, $021b4f4b5, $056b3c423,
    $0cfba9599, $0b8bda50f, $02802b89e, $05f058808, $0c60cd9b2, $0b10be924,
    $02f6f7c87, $058684c11, $0c1611dab, $0b6662d3d, $076dc4190, $001db7106,
    $098d220bc, $0efd5102a, $071b18589, $006b6b51f, $09fbfe4a5, $0e8b8d433,
    $07807c9a2, $00f00f934, $09609a88e, $0e10e9818, $07f6a0dbb, $0086d3d2d,
    $091646c97, $0e6635c01, $06b6b51f4, $01c6c6162, $0856530d8, $0f262004e,
    $06c0695ed, $01b01a57b, $08208f4c1, $0f50fc457, $065b0d9c6, $012b7e950,
    $08bbeb8ea, $0fcb9887c, $062dd1ddf, $015da2d49, $08cd37cf3, $0fbd44c65,
    $04db26158, $03ab551ce, $0a3bc0074, $0d4bb30e2, $04adfa541, $03dd895d7,
    $0a4d1c46d, $0d3d6f4fb, $04369e96a, $0346ed9fc, $0ad678846, $0da60b8d0,
    $044042d73, $033031de5, $0aa0a4c5f, $0dd0d7cc9, $05005713c, $0270241aa,
    $0be0b1010, $0c90c2086, $05768b525, $0206f85b3, $0b966d409, $0ce61e49f,
    $05edef90e, $029d9c998, $0b0d09822, $0c7d7a8b4, $059b33d17, $02eb40d81,
    $0b7bd5c3b, $0c0ba6cad, $0edb88320, $09abfb3b6, $003b6e20c, $074b1d29a,
    $0ead54739, $09dd277af, $004db2615, $073dc1683, $0e3630b12, $094643b84,
    $00d6d6a3e, $07a6a5aa8, $0e40ecf0b, $09309ff9d, $00a00ae27, $07d079eb1,
    $0f00f9344, $08708a3d2, $01e01f268, $06906c2fe, $0f762575d, $0806567cb,
    $0196c3671, $06e6b06e7, $0fed41b76, $089d32be0, $010da7a5a, $067dd4acc,
    $0f9b9df6f, $08ebeeff9, $017b7be43, $060b08ed5, $0d6d6a3e8, $0a1d1937e,
    $038d8c2c4, $04fdff252, $0d1bb67f1, $0a6bc5767, $03fb506dd, $048b2364b,
    $0d80d2bda, $0af0a1b4c, $036034af6, $041047a60, $0df60efc3, $0a867df55,
    $0316e8eef, $04669be79, $0cb61b38c, $0bc66831a, $0256fd2a0, $05268e236,
    $0cc0c7795, $0bb0b4703, $0220216b9, $05505262f, $0c5ba3bbe, $0b2bd0b28,
    $02bb45a92, $05cb36a04, $0c2d7ffa7, $0b5d0cf31, $02cd99e8b, $05bdeae1d,
    $09b64c2b0, $0ec63f226, $0756aa39c, $0026d930a, $09c0906a9, $0eb0e363f,
    $072076785, $005005713, $095bf4a82, $0e2b87a14, $07bb12bae, $00cb61b38,
    $092d28e9b, $0e5d5be0d, $07cdcefb7, $00bdbdf21, $086d3d2d4, $0f1d4e242,
    $068ddb3f8, $01fda836e, $081be16cd, $0f6b9265b, $06fb077e1, $018b74777,
    $088085ae6, $0ff0f6a70, $066063bca, $011010b5c, $08f659eff, $0f862ae69,
    $0616bffd3, $0166ccf45, $0a00ae278, $0d70dd2ee, $04e048354, $03903b3c2,
    $0a7672661, $0d06016f7, $04969474d, $03e6e77db, $0aed16a4a, $0d9d65adc,
    $040df0b66, $037d83bf0, $0a9bcae53, $0debb9ec5, $047b2cf7f, $030b5ffe9,
    $0bdbdf21c, $0cabac28a, $053b39330, $024b4a3a6, $0bad03605, $0cdd70693,
    $054de5729, $023d967bf, $0b3667a2e, $0c4614ab8, $05d681b02, $02a6f2b94,
    $0b40bbe37, $0c30c8ea1, $05a05df1b, $02d02ef8d);
var
  ResultLength,i:integer;
  Crc32: dword;
  Buffer:PByteArray;
begin
  f.Seek(0,soFromBeginning);

  Crc32:=$FFFFFFFF;
  GetMem(Buffer,BufferSize);
  repeat
    ResultLength:=f.Read(Buffer^[0],BufferSize);
    for i:=0 to ResultLength-1 do
      CRC32:=(CRC32 shr 8) xor CRC32Table[Buffer^[i] xor (CRC32 and $FF)];
  until ResultLength=0;
  FreeMem(Buffer);
  Result:=IntToHex(not(CRC32),8);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  DragAcceptFiles(Handle,True); // allow dropping of files

  with TINIFile.Create(extractfilepath(paramstr(0))+'Settings.ini') do begin
    Form1.Left:=ReadInteger('Settings','Left',100);
    Form1.Top:=ReadInteger('Settings','Top',100);
    Form1.Width:=ReadInteger('Settings','Width',500);
    Form1.Height:=ReadInteger('Settings','Height',300);
    Memo1.Height:=ReadInteger('Settings','Memo height',89);
    Free;
  end;

  if (paramcount>0) and fileexists(paramstr(1)) then LoadFile(paramstr(1));
  Splitter1.Visible:=False;
  Memo1.Visible:=False;
end;

// Takes a BCD byte which has been read as hex and outputs the proper hex value
// eg. BCD value 45 is read as h45 = d69, output value = h2D = d45
// Hard to describe... it just fixes BCDs, OK?
// It doesn't do error checking.
function BCDFix(input:byte):byte;
begin
  Result:=(input shr 4)*10+(input and $f);
end;

// Reads a null-terminated string from the specified offset
// File must be open
function ReadString(Offset:integer;F:TFileStream):string;
var
  c:char;
  amt:integer;
begin
  Result:='';
  if Offset<>$ffff then begin
    if Offset>F.Size then begin
      Result:='*** Warning! Offset beyond EOF ***';
      Exit;
    end;
    f.Seek(Offset,soFromBeginning);
    repeat
      amt:=f.Read(c,1);
      Result:=Result+c;
    until (c=#0) or (amt=0);
  end;
end;

procedure TForm1.LoadFile(filename:string);
var
  f:TFileStream;
  i:integer;
begin
  if Memo1.Visible then Form1.Height:=Form1.Height-Memo1.Height-Splitter1.Height;
  Memo1.Visible:=False;
  Splitter1.Visible:=False;

  f:=TFileStream.Create(filename,fmOpenRead);

  TreeView1.Items.BeginUpdate;
  TreeView1.Items.Clear;

  DisplayFileInfo(f,filename);
  DisplaySDSCHeader(f);
  if not (
    DisplaySegaHeader(f,$7ff0,false) or
    DisplaySegaHeader(f,$3ff0,false) or
    DisplaySegaHeader(f,$1ff0,false)
  ) then DisplaySegaHeader(f,$7ff0,true);
  DisplayCodemastersHeader(f);

  // Set SelectedIndex to ImageIndex, so when selected the image doesn't change
  for i:=0 to TreeView1.Items.Count-1 do TreeView1.Items[i].SelectedIndex:=TreeView1.Items[i].ImageIndex;

  TreeView1.FullExpand; // Fully expand tree
  TreeView1.Items.EndUpdate;

  f.Free;

end;

procedure TForm1.WMDROPFILES(var Message: TWMDROPFILES);
var
  NTstring: array[0..255] of char;
  FileDropped:string;
begin
  DragQueryFile(Message.drop,0,NTstring,255); // Get 1st dropped file
  FileDropped:=StrPas(NTString);              // Convert to a Delphi string
  dragfinish(message.drop);                   // Discard dropped file(s) data
  LoadFile(FileDropped);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  with TINIFile.Create(extractfilepath(paramstr(0))+'Settings.ini') do begin
    WriteInteger('Settings','Left',Form1.Left);
    WriteInteger('Settings','Top',Form1.Top);
    WriteInteger('Settings','Width',Form1.Width);

    if Memo1.Visible
    then WriteInteger('Settings','Height',Form1.Height-Memo1.Height-Splitter1.Height)
    else WriteInteger('Settings','Height',Form1.Height);

    WriteInteger('Settings','Memo height',Memo1.Height);

    Free;
  end;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  if Memo1.Visible and (Memo1.Height<Splitter1.MinSize)
  then TreeView1.Height:=TreeView1.Height-(Splitter1.MinSize-Memo1.Height);
end;

procedure TForm1.DisplaySDSCHeader(f:TFileStream);
var
  Title,ReleaseNotes,Author:string;
  MyTreeNode:TTreeNode;
  Header:TSDSCHeader;
begin
  if f.Size<$7ff0 then exit;

  f.Seek($7fe0,soFromBeginning);
  f.Read(Header,sizeof(header));
  if Header.SDSCChars='SDSC' then begin
    if Header.TitleOffset<>$ffff then Title:=ReadString(Header.TitleOffset,f);
    if Header.ReleaseNotesOffset<>$ffff then ReleaseNotes:=ReadString(Header.ReleaseNotesOffset,f);
    if (Header.AuthorOffset<>$ffff) and (Header.AuthorOffset<>$0000) then Author:=ReadString(Header.AuthorOffset,f);

    with Header,TreeView1.Items do begin
      MyTreeNode:=Add(nil,'SDSC header');
      MyTreeNode.ImageIndex:=12;

      if TitleOffset<>$ffff
      then AddChild(MyTreeNode,'Title = '+Title).ImageIndex:=0;

      if (AuthorOffset<>$ffff) and (AuthorOffset<>$0000)
      then AddChild(MyTreeNode,'Author = '+Author).ImageIndex:=16;

      AddChild(MyTreeNode,'Program version = '+Format('%d.%.2d',[BCDFix(MajorVersion),BCDFix(MinorVersion)])).ImageIndex:=14; // Add child value: version, padding minor version to 2 digits if necessary
      AddChild(MyTreeNode,'Release date = '+DateToStr(EncodeDate(BCDFix(ReleaseYear shr 8)*100+BCDFix(ReleaseYear and $ff),BCDFix(ReleaseMonth),BCDFix(ReleaseDay)))).ImageIndex:=3; // Add child value: release date

      if ReleaseNotesOffset<>$ffff then begin
        AddChild(MyTreeNode,'Release notes (see below)').ImageIndex:=0;  // Add child value: release notes (if there)
        if not Memo1.Visible then Form1.Height:=Form1.Height+Memo1.Height+Splitter1.Height;
        Memo1.Visible:=True;
        Splitter1.Visible:=True;
        Splitter1.Align:=alBottom;
        Memo1.Lines.SetText(Pchar(ReleaseNotes));
      end;
    end;
  end;
end;

procedure TForm1.DisplayFileInfo(f:TFileStream;filename:string);
var
  MyTreeNode:TTreeNode;
  fs : TFileStream;
begin
  with TreeView1.Items do begin

    MyTreeNode:=Add(nil,'File info'); MyTreeNode.ImageIndex:=4; // Add root node and note its value

    AddChild(MyTreeNode,'Filename = '+extractfilename(filename)).ImageIndex:=0; // Add child value: filename

    // Add child value: filesize
    AddChild(MyTreeNode,'Size = '+IntToStr(f.Size)+' bytes ('+FloatToStr(f.Size/$400)+'KB, '+FloatToStr(f.Size/$20000)+'Mbits)').ImageIndex:=9;

    // Add child value: CRC32
    AddChild(MyTreeNode,'CRC32 = '+CRCFile(f)).ImageIndex:=1;

    // FullSum
    AddChild(MyTreeNode,'Fullsum = $'+IntToHex(CalcChecksum(f,0,f.Size,0),4)).ImageIndex:=1;

    // Add child value: date
    AddChild(MyTreeNode,'Date and time = '+DateTimeToStr(FileDateToDateTime(FileAge(filename)))).ImageIndex:=3;

  end;
end;

function TForm1.DisplaySegaHeader(f:TFileStream;offset:integer;force:boolean):boolean;
var
  MyTreeNode:TTreeNode;
  Header:TSegaHeader;
  TempStr:string;
  i,CheckSumCalc,CodiesSegaChecksum,NumPages:integer;
begin
  result:=false;
  if f.Size<offset+16 then exit;

  f.Seek(offset,soFromBeginning);
  f.Read(Header,sizeof(header));
  if (Header.TMRSEGAChars='TMR SEGA')
  or force
  then with Header,TreeView1.Items do begin
    MyTreeNode:=Add(nil,'Sega header'); MyTreeNode.ImageIndex:=8; // Add root node and note its value

    TempStr:='';
    for i:=0 to 15 do
      if (integer(TMRSEGAChars[i])<32)
      or (integer(TMRSEGAChars[i])>127)
      then TempStr:=TempStr+'.'
      else TempStr:=TempStr+TMRSegaChars[i];
    AddChild(MyTreeNode,'Full header (ASCII) = '+TempStr).ImageIndex:=6;

    TempStr:='';
    for i:=0 to 15 do TempStr:=TempStr+' '+IntToHex(integer(TMRSegaChars[i]),2);
    AddChild(MyTreeNode,'Full header (hex) ='+TempStr).ImageIndex:=6;

    MyTreeNode:=AddChild(MyTreeNode,'Checksum'); MyTreeNode.ImageIndex:=7; // Add child node and note value

    if((RegionAndCartSize shr 4)<>4) then AddChild(MyTreeNode,'The region code suggests that this ROM doesn''t need a valid checksum.').ImageIndex:=11;

    AddChild(MyTreeNode,'From header = '+IntToHex(Checksum,4)).ImageIndex:=6; // Add child value: header checksum

    case (RegionAndCartSize and $F) of
    $a: begin CheckSumCalc:=CalcChecksum(f,    0, $1FEF,0); NumPages:=0; end;
    $b: begin CheckSumCalc:=CalcChecksum(f,    0, $3FEF,0); NumPages:=1; end;
    $c: begin CheckSumCalc:=CalcChecksum(f,    0, $7FEF,0); NumPages:=2; end;
    $d: begin CheckSumCalc:=CalcChecksum(f,    0, $bFEF,0); NumPages:=3; end;
    $e: begin CheckSumCalc:=CalcChecksum(f,$8000, $ffff,CalcChecksum(f,0,$7FEF,0)); NumPages:=4; end;
    $f: begin CheckSumCalc:=CalcChecksum(f,$8000,$1ffff,CalcChecksum(f,0,$7FEF,0)); NumPages:=8; end;
    $0: begin CheckSumCalc:=CalcChecksum(f,$8000,$3ffff,CalcChecksum(f,0,$7FEF,0)); NumPages:=16; end;
    $1: begin CheckSumCalc:=CalcChecksum(f,$8000,$7ffff,CalcChecksum(f,0,$7FEF,0)); NumPages:=32; end;
    $2: begin CheckSumCalc:=CalcChecksum(f,$8000,$fffff,CalcChecksum(f,0,$7FEF,0)); NumPages:=64; end;
    else
      // invalid number
      CheckSumCalc:=Checksum+1; // to guarantee non-equality
      NumPages:=-1;
    end;

    // try Codemasters paging checksum if that failed
    if(CheckSumCalc<>Checksum) and (NumPages>1) // it'd pass anyway if NumPages was 0,1,2
    then CodiesSegaChecksum:=CalcChecksum(f,$4000,$7FEF,CalcChecksum(f,0,$3FFF,0)*(NumPages-1))
    else CodiesSegaChecksum:=-1;

    if(CodiesSegaChecksum<>Checksum) then begin
      TempStr:='Calculated = '+IntToHex(ChecksumCalc,4)+' (';
      if Checksum=CheckSumCalc then TempStr:=TempStr+'OK' else TempStr:=TempStr+'bad!'; // Indicate whether chucksums match
      AddChild(MyTreeNode,TempStr+')').ImageIndex:=1; // Add child value: actual checksum
    end else begin
      AddChild(MyTreeNode,'Calculated (Codemasters mapper) = '+IntToHex(CodiesSegaChecksum,4)+' (OK)').ImageIndex:=1; // Add child value: actual checksum
    end;

    // Add child value: checksum range
    TempStr:='$'+IntToHex(RegionAndCartSize and $f,1)+' (';
    case NumPages of
    -1: TempStr:=TempStr+'invalid';
    0: TempStr:=TempStr+'8KB';
    else
      TempStr:=TempStr+IntToStr(NumPages*16)+'KB'
    end;
    AddChild(MyTreeNode,'Rom size = '+TempStr+')').ImageIndex:=2;

    MyTreeNode:=MyTreeNode.Parent; // Select "Sega header" root node again

    // Add child value: Region code
    TempStr:='Region code = $'+IntToHex(RegionAndCartSize shr 4,1)+' (';
    case (RegionAndCartSize shr 4) of
      $3:TempStr:=TempStr+'SMS Japan';
      $4:TempStr:=TempStr+'SMS Export';
      $5:TempStr:=TempStr+'GG Japan';
      $6:TempStr:=TempStr+'GG Export';
      $7:TempStr:=TempStr+'GG International';
    else
      TempStr:=TempStr+'Unknown';
    end;
    AddChild(MyTreeNode,TempStr+')').ImageIndex:=5;

    if (RegionAndCartSize shr 4 in [$3,$4]) then begin
      // Add child value: product number. Do some interpreting of its value.
      TempStr:='Product number = ';
      if (Version and $f0)=$20 then TempStr:=TempStr+'2';
      TempStr:=TempStr+IntToHex(PartNumber,4)+' (';
      case PartNumber of
        $0500..$0599: begin System.Insert('C-',TempStr,18); System.Delete(TempStr,20,1); TempStr:=TempStr+'Japanese'; end;
        $1300..$1399: begin System.Insert('G-',TempStr,18); TempStr:=TempStr+'Japanese'; end;
        $3901: TempStr:=TempStr+'Parker Brothers (incorrect number)'; // They actually have numbers 4350,60,70 but internally 2 have 3901 and 1 has 0000
        $4001..$4499: TempStr:=TempStr+'The Sega Card (32KB)';
        $4501..$4507,$4580..$4584: TempStr:=TempStr+'The Sega Cartridge (32KB)';
        $5051..$5199: TempStr:=TempStr+'The Mega Cartridge (128KB)';
        $5500..$5599: TempStr:=TempStr+'The Mega Plus Cartridge (128KB with battery-backed RAM)';
        $5044,$6001..$6081: TempStr:=TempStr+'The Combo Cartridge';
        $7001..$7499: TempStr:=TempStr+'The Two-Mega Cartridge (256KB)';
        $7500..$7599: TempStr:=TempStr+'The Two-Mega Plus Cartridge (256KB with battery-backed RAM)';
        $8001..$8499: TempStr:=TempStr+'The 3-Dimensional Mega Cartridge';
        $9001..$9499: TempStr:=TempStr+'The Four-Mega Cartridge (512KB)';
        $9500..$9599: TempStr:=TempStr+'The Four-Mega Plus Cartridge (512KB with battery-backed RAM)';
      else
        TempStr:=TempStr+'Unknown';
      end;
      if (Version and $f0)=$20 then TempStr:=TempStr+' (3rd party)';
      AddChild(MyTreeNode,TempStr+')').ImageIndex:=13;
    end else begin // GG games
      // this is nasty but I can't be bothered to clean it up, it works OK
      i:=(Version shr 4 * $10000) + PartNumber;

      TempStr:='Product number = '+IntToStr(Version shr 4)+IntToHex(PartNumber,4)+' (';

      case (i shr 12) of
        2,3: begin
                System.Delete(TempStr,18,1);
                TempStr:=TempStr+'Sega';
                if i shr 12 = 3 then begin
                  System.Insert('G-',TempStr,18);
                  TempStr:=TempStr+' Japan';
                end else TempStr:=TempStr+' of America';
                case (PartNumber shr 8) of
                  $20..$2f: TempStr:=TempStr+', >=128KB, Export or International)';
                  $31: TempStr:=TempStr+', 32KB)';
                  $32: TempStr:=TempStr+', 128KB)';
                  $33: TempStr:=TempStr+', >=256KB)';
                else
                  TempStr:=TempStr+')';
                end;
              end;
        $11: TempStr:=TempStr+'Taito)';
        $14: TempStr:=TempStr+'Namco)';
        $15: TempStr:=TempStr+'SunSoft)';
        $22: TempStr:=TempStr+'Micronet)';
        $23: TempStr:=TempStr+'Vic Tokai/SIMS [only one])';
        $25: TempStr:=TempStr+'NCS [only one])';
        $26: TempStr:=TempStr+'Sigma Enterprises [only one])';
        $28: TempStr:=TempStr+'Genki [only one])';
        $32: TempStr:=TempStr+'Wolf Team [only one])';
        $33: TempStr:=TempStr+'Kaneko [only one])';
        $44: TempStr:=TempStr+'Sanritsu/SIMS)';
        $45: TempStr:=TempStr+'Game Arts/Studio Alex [only one])';
        $48: TempStr:=TempStr+'Tengen/Time Warner)';
        $49: TempStr:=TempStr+'Telenet Japan [only one])';
        $50: TempStr:=TempStr+'EA)';
        $51: TempStr:=TempStr+'SystemSoft [only one])';
        $52: TempStr:=TempStr+'Microcabin)';
        $53: TempStr:=TempStr+'Riverhill Soft)';
        $54: TempStr:=TempStr+'ASCII corp. [only one])';
        $60: TempStr:=TempStr+'Victor/Loriciel/Infogrames [only one])';
        $65: TempStr:=TempStr+'Tatsuya Egama/Syueisya/Toei Anumaition/Tsukuda Ideal [only one])';
        $66: TempStr:=TempStr+'Compile)';
        $68: TempStr:=TempStr+'GRI [only one])';
        $70: TempStr:=TempStr+'Virgin)';
        $79: TempStr:=TempStr+'US Gold)';
        $81: TempStr:=TempStr+'Acclaim)';
        $83: TempStr:=TempStr+'GameTek)';
        $87: TempStr:=TempStr+'Mindscape)';
        $88: TempStr:=TempStr+'Domark)';
        $93: TempStr:=TempStr+'Sony)';
        $A0: TempStr:=TempStr+'THQ)';
        $A3: TempStr:=TempStr+'SNK)';
        $A4: TempStr:=TempStr+'Microprose [only one])';
        $B2: TempStr:=TempStr+'Disney [only one])';
        $C5: TempStr:=TempStr+'Beam Software P/L)';
        $D3: TempStr:=TempStr+'Bandai)';
        $D9: TempStr:=TempStr+'Viacom)';
        $E9: TempStr:=TempStr+'Infocom/Gremlin [only one])';
        $F1: TempStr:=TempStr+'Infogrames)';
        $F4: TempStr:=TempStr+'Technos Japan Corp. [only one])';
      else
        TempStr:=TempStr+'Unknown)';
      end;
      if (Version shr 4>0) then System.Insert('T-',TempStr,18);
      AddChild(MyTreeNode,TempStr).ImageIndex:=13;
    end;

    // Add child value: version byte
    AddChild(MyTreeNode,'Version = '+copy(IntToHex(Version,2),2,1)).ImageIndex:=14;

    // Add child value: reserved word
    AddChild(MyTreeNode,'Reserved word = '+IntToHex(UnknownValue,4)).ImageIndex:=11;
    result:=true;
  end;

end;

procedure TForm1.DisplayCodemastersHeader(f:TFileStream);
var
  MyTreeNode:TTreeNode;
  Header:TCodemastersHeader;
  CheckSumCalc:integer;
  TempStr:string;
  timestamp:TDateTime;
begin
  if(f.Size<$7ff0) then exit;

  f.Seek($7fe0,soFromBeginning);
  f.Read(Header,sizeof(Header));

  // check it seems to be a likely header
  // I could do more checks...
  // 0 = -0 so blank areas pass this check; they tend to fail the date encode, though.
  if(Header.InverseChecksum = word(-Header.Checksum))
  then with Header,TreeView1.Items do begin
    try
      timestamp:=EncodeDate(BCDFix(Year)+1900,BCDFix(Month),BCDFix(Day))+
                 EncodeTime(BCDFix(Hour),BCDFix(Minute),0,0);
      MyTreeNode:=Add(nil,'Codemasters header'); MyTreeNode.ImageIndex:=15;
      AddChild(MyTreeNode,'Date and time = '+DateTimeToStr(timestamp)).ImageIndex:=3;
      MyTreeNode:=AddChild(MyTreeNode,'Checksum'); MyTreeNode.ImageIndex:=7;
      AddChild(MyTreeNode,'From header = '+IntToHex(Checksum,4)).ImageIndex:=6;
      CheckSumCalc:=CalcCodiesChecksum(f,NumPages);
      TempStr:='Calculated = '+IntToHex(ChecksumCalc,4)+' (';
      if Checksum=CheckSumCalc then TempStr:=TempStr+'OK' else TempStr:=TempStr+'bad!';
      AddChild(MyTreeNode,TempStr+')').ImageIndex:=1;
      AddChild(MyTreeNode,'Rom size = '+IntToStr(NumPages)+' pages ('+IntToStr(NumPages*16)+'KB)').ImageIndex:=2;
    except
      // do nothing if date/time encoding fails because that signifies an invalid heaer
    end;
  end;
end;

end.



{
  function lines() {
    const {start, end} = location();
  	return [start.line, end.line - 1];
  }
}

Document =
  BlankLine?
  fragments:MultiLineBlock*
  {
    return { fragments }
  }

// Blocks

MultiLineBlock =
  Indent?
  words:(Word Spnl?)+
  BlockEnd
  {
    return {
      text: words.map(word => word[0]).join(' '),
      lines: lines(),
    }
  }

// Format Tokens

Spnl =          Sp (NewLine Indent)?
Indent =        '   '
BlockEnd =      NewLine (NewLine / Eof)

// Base Tokens

BlankLine =     NewLine
SpaceChar =     ' ' / '\t'
NonSpaceChar =  !SpaceChar !NewLine .
NewLine =       '\n' / '\r' '\n'?
Eof =           !. // End of file
Sp =            SpaceChar*
Word =          NonSpaceChar+ { return text() }

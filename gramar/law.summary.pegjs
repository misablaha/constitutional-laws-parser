
{
  function capitalize(string) {
    return string.charAt(0).toUpperCase() + string.toLowerCase().slice(1);
  }

  const list = {
    path: [],

    walkIn(bullet) {
      if(this.path.includes(bullet.type)) {
        return false;
      } else {
        this.path.unshift(bullet.type);
        level.walkIn();
        return true;
      }
    },

    walkOut() {
      this.path.shift();
      level.walkOut();
      return true;
    },

  };

  const level = {
    ranges: [],
    closedRange: [],

    walkIn() {
      this.ranges.push([]);
      return true;
    },

    walkOut() {
      this.closedRange = this.ranges.pop();
      return true;
    },

    addParagraph(number) {
      this.ranges.forEach(range => range.push(number));
      return true;
    },

    level() {
      return this.ranges.length + 1;
    },

    getParagraphRange() {
      const result = [];
      const range = this.closedRange;
      if (range.length) result.push("§ " + range.shift());
      if (range.length) result.push("§ " + range.pop());

      return result.join(" - ");
    },
  }

  function lines() {
    const {start, end} = location();
    return [start.line, end.line - 1];
  }

}

Document =
  BlankLine?
  head:Head
  novels:Changes?
  issuedBy:IssuedBy
  summary:Part*
  remain:.*
  {
    return {
      head,
      novels,
      issuedBy,
      summary,
      // remain
    }
  }

// Structure

HeadLine = PartHeadLine / ChapterHeadLine / ParagraphHeadLine

PartHeadLine =
  Indent "ČÁST" Sp number:WrittenNumber BlockEnd
  { return {
    type: "PART_HEADLINE",
    text: "ČÁST " + number.text,
    number: number.number,
    level: level.level(),
    lines: lines(),
  } }

ChapterHeadLine =
  Indent "HLAVA" Sp number:WrittenNumber BlockEnd
  { return {
    type: "CHAPTER_HEADLINE",
    text: "HLAVA " + number.text,
    number: number.number,
    level: level.level(),
    lines: lines(),
  } }

ParagraphHeadLine =
  Indent "§" Sp number:Word BlockEnd
  { return {
    type: "PARAGRAPH_HEADLINE",
    text: "§ " + number,
    number,
    level: level.level(),
    lines: lines(),
  } }

Part =
  headLine:PartHeadLine
  &{return level.walkIn()}
  title:SingleLineBlock
  content:(Chapter / Paragraph)*
  &{return level.walkOut()}
  {
    return {
      type: "PART",
      caption: headLine.text + " - " + title.text,
      headLine,
      title: Object.assign(title, {type: "PART_TITLE"}),
      number: headLine.number,
      level: level.level(),
      range: level.getParagraphRange(),
      lines: lines(),
      content,
    }
  }

Chapter =
  headLine:ChapterHeadLine
  &{return level.walkIn()}
  title:SingleLineBlock
  content:(Group / Paragraph)*
  &{return level.walkOut()}
  {
    return {
      type: "CHAPTER",
      caption: headLine.text + " - " + title.text,
      headLine,
      title: Object.assign(title, {type: "CHAPTER_TITLE"}),
      number: headLine.number,
      level: level.level(),
      range: level.getParagraphRange(),
      lines: lines(),
      content,
    }
  }

Group =
  title:(!HeadLine SingleLineBlock)
  &{return level.walkIn()}
  content:Paragraph*
  &{return level.walkOut()}
  {
    return {
      type: "GROUP",
      caption: title[1].text,
      title: Object.assign(title[1], {type: "GROUP_TITLE"}),
      level: level.level(),
      range: level.getParagraphRange(),
      lines: lines(),
      content,
    }
  }

Paragraph =
  headLine:ParagraphHeadLine
  &{return level.addParagraph(headLine.number)}
  &{return level.walkIn()}
  content:(SectionParagraph / ListParagraphWithoutTitle / ContentParagraph / TitleOnlyParagraph)
  &{return level.walkOut()}
  {
    return {
      type: 'PARAGRAPH',
      caption: headLine.text + (content.title && content.title.text ? (" - " + content.title.text) : ''),
      headLine,
      title: content.title && Object.assign(content.title, {
        type: "PARAGRAPH_TITLE",
      }),
      number: headLine.number,
      level: level.level(),
      lines: lines(),
      content: content.content,
    }
  }

SectionBullet =
  "(" bullet:UInt ")" SpaceChar+
  { return { type: "SECTION_BULLET", caption: "(" + bullet + ")", number:bullet } }

Section =
  Indent bullet:SectionBullet
  content:ContentBlock
  {
    return {
      type: 'SECTION',
      caption: bullet.caption,
      number: bullet.number,
      level: level.level(),
      lines: lines(),
      content: content,
    }
  }

// Paragraph content types

SectionParagraph =
  title:(!HeadLine MultiLineBlock)?
  content:Section+
  { return { title: title && title[1], content } }

ListParagraphWithoutTitle =
  content:ListContent
  { return { title: null, content } }

ContentParagraph =
  title:(!HeadLine SingleLineBlock)?
  content:ContentBlock
  { return { title: title && title[1], content } }

TitleOnlyParagraph =
  title:(!HeadLine SingleLineBlock)
  { return { title: title[1], content: null } }

// Content

ContentBlock = ListContent / QuoteContent / BaseContent

BaseContent =
  text: (!HeadLine MultiLineBlock)
  { return [text[1]] }

ListContent =
  text: (!HeadLine MultiLineBlock)
  list: List
  continuation: (!HeadLine MultiLineBlock)?
  {
    const result = [];
    result.push(text[1]);
    result.push(list);
    if (continuation && continuation[1]) result.push(continuation[1]);

    return result;
  }

QuoteContent =
  text: (!HeadLine MultiLineBlock)
  list: Quote
  continuation: (!HeadLine MultiLineBlock)?
  {
    const result = [];
    result.push(text[1]);
    result.push(list);
    if (continuation && continuation[1]) result.push(continuation[1]);

    return result;
  }

Quote =
  Indent? "„"
  content:(!QuoteMarks .)*
  "“" "."? BlockEnd?
  {
    return {
      type: "QUOTE",
      text: text(),
      lines: lines(),
    }
  }

MultiLineBlockWithoutQuoteMarks =
  Indent?
  !Bullet !SectionBullet
  words:(WordWithoutQuoteMarks Spnl?)+
  BlockEnd?
  {
    return {
      type: "TEXT",
      text: words.map(word => word[0]).join(' ')
    }
  }

// Lists

Bullet = LetterBullet / NumberBullet

LetterBullet =
  bullet:[a-z]+ ')' SpaceChar+
  { return { type: "LETTER_BULLET", caption: bullet.join('') + ")", number:bullet.join('') } }

NumberBullet =
  bullet:UInt '.' SpaceChar+
  { return { type: "NUMBER_BULLET", caption: bullet + ".", number:bullet } }

List =
  content: ListItem+
  {
    return {
      type: "LIST",
      lines: lines(),
      content,
    }
  }

ListItem =
  Indent bullet:Bullet
  &{return list.walkIn(bullet)}
  content:ContentBlock
  &{return list.walkOut()}
  {
    return {
      type: "LIST_ITEM",
      caption: bullet.caption,
      number: bullet.number,
      level: level.level(),
      lines: lines(),
      content,
    }
  }



Head =
  Indent lawNo:LawNo BlockEnd
  type:SingleLineBlock
  whichOne:(!Issued SingleLineBlock)?
  issued:Issued
  title:MultiLineBlock
  alias:(Indent Comment BlockEnd)?
  {
    let short
    if (alias) {
      short = capitalize(alias[1])
    } else if (whichOne) {
      short = capitalize(type.text) + ' ' + title
    } else {
      short = capitalize(title.text)
    }

    return {
      number: lawNo,
      type: Object.assign(type, {type: "LAW_TYPE"}),
      issuedAt: issued,
      title: Object.assign(title, {type: "LAW_TITLE"}),
//      short: short,
//      title: capitalize(type.text) + ' ' + (whichOne ? whichOne[1] + ' ' : '') + title.text,
    }
  }

Changes =
  changes:ChangeLine+
  {
    return changes.reduce((acc, changes) => acc.concat(changes))
  }

ChangeLine =
  Indent 'Změna: '
  changes:(LawNo Comment? (Comma / BlockEnd))+
  {
    return changes.map(change => change[0])
  }

Issued =
  Indent
  "ze dne " date:Date Dellimiter
  BlockEnd
  {
    return {
      type: "ISSUE_DATE",
      text: "ze dne " + date.text,
      date,
      level: level.level(),
      lines: lines(),
    }
  }

IssuedBy =
  Indent
  text:(WordWithoutPunctuation Spnl?)+ ':'
  BlockEnd
  {
    return {
      type: "ISSUED_BY",
      text: text.map(word => word[0]).join(' ') + ':',
      level: level.level(),
      lines: lines(),
    }
  }


// Fragments

LawNo =
  number:UInt '/' year:UInt Spnl 'Sb.'
  {
    return {
      type: "LAW_NUMBER",
      text: text(),
      code: year + '-' + number,
      number: number,
      year: year,
      level: level.level(),
      lines: lines(),
    }
  }

// Numbers

WrittenNumber = No14 / No13 / No12 / No11 / No10 / No9 /
  No8 / No7 / No6 / No5 / No4 / No3 / No2 / No1

No1  = ("PRVNÍ" / "I") { return {text: text(), number: 1} }
No2  = ("DRUHÁ" / "II") { return {text: text(), number: 2} }
No3  = ("TŘETÍ" / "III") { return {text: text(), number: 3} }
No4  = ("ČTVRTÁ" / "IV") { return {text: text(), number: 4} }
No5  = ("PÁTÁ" / "V") { return {text: text(), number: 5} }
No6  = ("ŠESTÁ" / "VI") { return {text: text(), number: 6} }
No7  = ("SEDMÁ" / "VII") { return {text: text(), number: 7} }
No8  = ("OSMÁ" / "VIII") { return {text: text(), number: 8} }
No9  = ("DEVÁTÁ" / "IX") { return {text: text(), number: 9} }
No10 = ("DESÁTÁ" / "X") { return {text: text(), number: 10} }
No11 = ("JEDENÁCTÁ" / "XI") { return {text: text(), number: 11} }
No12 = ("DVANÁCTÁ" / "XII") { return {text: text(), number: 12} }
No13 = ("TŘINÁCTÁ" / "XIII") { return {text: text(), number: 13} }
No14 = ("ČTRNÁCTÁ" / "XIV") { return {text: text(), number: 14} }

// Dates

Date =
  day:UInt '.' Sp month:Month Sp year:UInt
  { return {text: text(), day, month, year, date: new Date(year, month - 1, day)} }

Month =
  January / February / March / April / May / July / June /
  August / September / October / November / December

January =     'leden'i / 'ledna'i  { return 1 }
February =    'února'i / 'únor'i  { return 2 }
March =       'březen'i / 'března'i  { return 3 }
April =       'duben'i / 'dubna'i  { return 4 }
May =         'květen'i / 'května'i  { return 5 }
June =        'červen'i / 'června'i  { return 6 }
July =        'červenec'i / 'července'i  { return 7 }
August =      'srpen'i / 'srpna'i  { return 8 }
September =   'září'i / 'září'i  { return 9 }
October =     'říjen'i / 'října'i  { return 10 }
November =    'listopad'i / 'listopadu'i  { return 11 }
December =    'prosinec'i / 'prosince'i  { return 12 }

// Blocks

SingleLineBlock =
  Indent?
  !Bullet !SectionBullet
  words:(Word Sp?)+
  BlockEnd
  {
    return {
      type: "TEXT",
      text: words.map(word => word[0]).join(' '),
      level: level.level(),
      lines: lines(),
    }
  }

MultiLineBlock =
  Indent?
  !Bullet !SectionBullet
  words:(Word Spnl?)+
  BlockEnd
  {
    return {
      type: "TEXT",
      text: words.map(word => word[0]).join(' '),
      level: level.level(),
      lines: lines(),
    }
  }

// Punctuation

WordWithoutPunctuation = (!Punctuation NonSpaceChar)+ { return text() }
WordWithoutQuoteMarks = (!QuoteMarks NonSpaceChar)+ { return text() }

Punctuation =   Comma / Colon / Dot
Comma =         Sp ',' Spnl { return ',' }
Colon =         Sp ':' Spnl { return ':' }
Dot =           Sp '.' Spnl { return '.' }
QuoteMarks =    '„' / '“'

// Format Tokens

Dellimiter =    Comma / Sp
Spnl =          Sp (NewLine Indent)?
Indent =        '   '
Comment =       Sp '(' comment:[^)]+ ')' { return comment.join('')}
BlockEnd =      NewLine (NewLine / Eof)

// Base Tokens

BlankLine =     NewLine
SpaceChar =     ' ' / '\t'
NonSpaceChar =  !SpaceChar !NewLine .
InlineChar =    !NewLine .
NewLine =       '\n' / '\r' '\n'?
Eof =           !. // End of file
Sp =            SpaceChar* {return ' '}

// Data types

Char =          NonSpaceChar / Sp
Digit =         [0-9]
Zero =          '0'
Digit1_9 =      [1-9]
Minus =         '-'
Word =          NonSpaceChar+ { return text() }
Int =           Zero / (Minus? Digit1_9 Digit*) { return parseInt(text(), 10) }
UInt =          Zero / (Digit1_9 Digit*) { return parseInt(text(), 10) }

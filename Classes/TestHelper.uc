///////////////////////////////////////////////////////////////////////////////
// filename:    TestHelper.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     used for testing perposes only
///////////////////////////////////////////////////////////////////////////////

class TestHelper extends UTelAdSEHelper config(UTHangman);

var config array<string> wordlist;

function bool Init()
{
  log("[~] Loading TestHelper class, ONLY FOR TESTING DUDE", 'UTelAdSE');
  return true;
}

function bool ExecBuiltin(string command, array< string > args, out int hideprompt, UTelAdSEConnection connection)
{
  switch (command)
  {
    case "stdin" : stealSTDIN(args, connection); hideprompt=1; return true;
    case "colorise" : colorTest(connection); return true;
  }
  return false;
}

function stealSTDIN(array< string > args, UTelAdSEConnection connection)
{
  connection.captureSTDIN(self);
  if (args.length > 0)
  {
    if (args[0] == "hangman")
    {
      connection.CLSR();
      connection.MoveCursor(0,0);
      connection.session.setValue("hangman_enabled", "1", true);
      connection.SendLine("========================================");
      connection.SendLine("=       "$Bold("Welcome to UT2003 Hangman")$"      =");
      connection.SendLine("= You can quit any time by pressing "$Bold("^C")$" =");
      connection.SendLine("=        "$Blink("Press any key to begin")$"        =");
      connection.SendLine("========================================");
      connection.session.setValue("hangman_endgame", "1", true);
    }
  }
}

function colorTest(UTelAdSEConnection connection)
{
  local int i, j;
  local string tmp;
  for (i=0; i < int(connection.session.getValue("TERM_HEIGHT", "25"))-1; i++)
  {
    tmp = "";
    for (j=0; j < int(connection.session.getValue("TERM_WIDTH", "80")); j++)
    {
      tmp = tmp$Colorise(Chr(rand(27)+65), ETerm_color(rand(8)), ETerm_color(rand(8)));
    }
    connection.SendLine(tmp);
  }
}

function HandleInput(string Text, UTelAdSEConnection connection)
{
  if (Asc(Left(Text,1)) == 3)
  {
    connection.session.setValue("hangman_enabled", "0", true);
    connection.SendLine("Received ^C returning STDIN");
    connection.SendPrompt();
    connection.releaseSTDIN();
    return;
  }
  if (connection.session.getValue("hangman_enabled") == "1") playHangman(text, connection);
  else connection.SendLine("Received input:"$text);
}

// Hangman game
// you can think of this game as an easter egg

function string getHandmanWord()
{
  return wordlist[Rand(wordlist.length)];
}

function string maskWord(string word, string chars)
{
  local int i;
  local string result;
  for (i = 0; i < len(word); i++)
  {
    if (InStr(chars, Mid(word, i, 1)) != -1) result = result$Mid(word, i, 1);
      else result = result$".";
  }
  return result;
}

function startHangman(UTelAdSEConnection connection)
{
  local string word;
  connection.CLSR();
  connection.MoveCursor(0,0);
  connection.session.setValue("hangman_endgame", "0", true);
  connection.session.setValue("hangman_wrongs", "0", true);
  connection.session.setValue("hangman_guesses", "0", true);
  word = caps(getHandmanWord());
  connection.session.setValue("hangman_word", word, true);
  connection.session.setValue("hangman_chars", "", true);

  connection.SendLine("");
  drawHangman(connection, 0, 0, maskWord(word,""), "");
  connection.SendLine("");
}

function playHangman(string Text, UTelAdSEConnection connection)
{
  local string char, guessedword, chars, word;
  local int wrongs, guesses;

  char = Caps(Left(Text, 1));
  if (connection.session.getValue("hangman_endgame") == "1")
  {
    startHangman(connection);
    return;
  }
  if ((char < "A") || (char > "Z")) return;

  wrongs = int(connection.session.getValue("hangman_wrongs", "0"));
  guesses = int(connection.session.getValue("hangman_guesses", "0"));
  word = connection.session.getValue("hangman_word");
  chars = connection.session.getValue("hangman_chars");
  
  if (InStr(chars, char) == -1)
  {
    chars = chars$char;
    connection.session.setValue("hangman_chars", chars, true);
    guesses++;
    connection.session.setValue("hangman_guesses", string(guesses), true);

    if (InStr(word, char) == -1)
    {
      wrongs++;
      connection.session.setValue("hangman_wrongs", string(wrongs), true);
    }

    guessedword = maskWord(word,chars);
    connection.SendText(Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A"$Chr(27)$"[A");
    drawHangman(connection, guesses, wrongs, guessedword, chars);
    if (word == guessedword)
    {
      connection.SendLine("--- Congratulations --- press any for a new game");
      connection.session.setValue("hangman_endgame", "1", true);
    }
    else if (wrongs < 7) connection.SendLine("");
    else {
      connection.SendLine("--- GAME OVER, the correct word was: "$word$" --- press any for a new game");
      connection.session.setValue("hangman_endgame", "1", true);
    }
  }
}

function drawHangman(UTelAdSEConnection connection, int guesses, int wrongs, string guessedword, string chars)
{
  local string tmp;
  connection.SendLine("     ______     ");
  connection.SendLine("     |    |     Guessed:"$Chr(9)@chars);
  if (wrongs > 0) tmp = "O"; else tmp = " ";
  connection.SendLine("     |    "$tmp$"     Tries:"$Chr(9)$Chr(9)@string(guesses));
  if (wrongs > 6) tmp = "/|\\"; 
  else if (wrongs > 4) tmp = "/| ";
  else if (wrongs > 1) tmp = " | "; 
  else tmp = "   ";
  connection.SendLine("     |   "$tmp$"    ");
  if (wrongs > 2) tmp = "|"; else tmp = " ";
  connection.SendLine("     |    "$tmp$"     ");
  if (wrongs > 5) tmp = "/ \\"; 
  else if (wrongs > 3) tmp = "/  ";
  else tmp = "   ";
  connection.SendLine("     |   "$tmp$"    ");
  connection.SendLine("   __|_____     ");
  connection.SendLine("   |      |___  ");
  connection.SendLine("   |_________|  ");
  connection.SendLine("");
  connection.SendLine("Word:"$Chr(9)@guessedword);
}

defaultproperties
{
  wordlist(0)="UTelAdSE"
  wordlist(1)="Unreal"
  wordlist(2)="Tournament"
  wordlist(3)="Hangman"
  wordlist(4)="Sniper"
  wordlist(5)="Frags"
  wordlist(6)="Cheater"
  wordlist(7)="Administrator"
  wordlist(8)="godlike"
  wordlist(9)="epic"
  wordlist(10)="camper"
  wordlist(11)="berserk"
  wordlist(12)="invisible"
  wordlist(13)="adrenaline"
  wordlist(14)="Mercenary"
  wordlist(15)="Juggernaut"
  wordlist(16)="Apocalypse"
  wordlist(17)="Crusaders"
  wordlist(18)="DragonBreath"
  wordlist(19)="IronGuard"
  wordlist(20)="Nightstalkers"
  wordlist(21)="elmuerte"
  wordlist(22)="PainMachine"
  wordlist(23)="ColdSteel"
  wordlist(24)="Venom"
  wordlist(25)="Domination"
  wordlist(26)="Xan"
  wordlist(27)="Affirmative"
  wordlist(28)="Deathmatch"
  wordlist(29)="BoneCrushers"
  wordlist(30)="InstaGib"
  wordlist(31)="Championship"
}
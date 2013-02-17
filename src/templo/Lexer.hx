package templo;

import String in StdString;
import templo.Ast;

enum TokenDef {
	// element
	Comment(v:String);
	Node(v:String);
	Macro(v:String);
	DoubleDot;
	Data(v:String);
	EndNode(v:String);
	CDataBegin;
	CDataEnd;
	// node
	NodeContent(v:Bool);
	// attrib value
	Quote(v:Bool);
	// expr
	Dot;
	Int(v:Int);
	Float(v:String);
	String(v:String);
	Ident(v:String);
	Kwd(v:Keyword);
	Comma;
	ParentOpen;
	ParentClose;
	BraceOpen;
	BraceClose;
	BracketOpen;
	BracketClose;
	Op(v:Op);
	Unop(v:Unop);
	Question;
	// eof
	Eof;
}

typedef Token = {
	tok: TokenDef,
	pos: hxparse.Lexer.Pos
}

enum Keyword {
	If;
	Else;
	Var;
	While;
	Do;
	For;
	Break;
	Continue;
	Function;
	Return;
	This;
	Try;
	Catch;
	Default;
	Switch;
	Case;
	Ignore;
	Literal;
}

enum ErrorMsg {
	InvalidOp(s:String);
	InvalidEscape;
}

class Lexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static inline var attr = "[a-zA-Z_][-:a-zA-Z0-9_]*";
	static inline var ident = "[a-zA-Z_][a-zA-Z0-9_]*";
	static inline var spaces = "[ \r\t\n]+";
	static var bom = StdString.fromCharCode(239) + StdString.fromCharCode(187) + StdString.fromCharCode(191);

	@:ruleHelper static var macroRule = "$$" + ident => mk(lexer, Macro(lexer.current.substr(2)));
	@:ruleHelper static var dblDot = "::" => mk(lexer, DoubleDot);

	static var buf = new StringBuf();

	static inline function mk(l, t) {
		return {
			tok: t,
			pos: l.curPos()
		}
	}

	static inline function mkData(l:hxparse.Lexer) {
		return mk(l, Data(l.current));
	}

	static inline function mkInt(l:hxparse.Lexer) {
		return mk(l, Int(Std.parseInt(l.current)));
	}

	static inline function mkFloat(l:hxparse.Lexer) {
		return mk(l, Float(l.current));
	}

	static function mkIdent(l:hxparse.Lexer) {
		var kwd = keywords.get(l.current);
		return
			if (kwd != null)
				mk(l, Kwd(kwd));
			else
				mk(l, Ident(l.current));
	}

	static var keywords = @:mapping Keyword;
	
	static var ops = [
		"+" => OpAdd,
		"*" => OpMult,
		"/" => OpDiv,
		"-" => OpSub,
		"=" => OpAssign,
		"==" => OpEq,
		"!=" => OpNotEq,
		">=" => OpGte,
		"<=" => OpLte,
		">" => OpGt,
		"<" => OpLt,
		"&" => OpAnd,
		"|" => OpOr,
		"^" => OpXor,
		"&&" => OpBoolAnd,
		"||" => OpBoolOr,
		">>" => OpShr,
		">>>" => OpUShr,
		"<<" => OpShl,
		"%" => OpMod,
		"~=" => OpCompare
	];
	
	static var unops = [
		"++" => Increment,
		"--" => Decrement,
		"!" => Not,
		"-" => Neg
	];
	
	static public var element = @:rule [
		"" => mk(lexer,Eof),
		bom => lexer.token(element),
		"<" + attr => mk(lexer,Node(lexer.current.substr(1))),
		macroRule,
		"<!--" => {
			var p1 = lexer.curPos();
			buf = new StringBuf();
			buf.add("<!--");
			var p2 = lexer.token(comment);
			{
				tok: Comment(buf.toString() + "-->"),
				pos: hxparse.Lexer.posUnion(p1,p2)
			}
		},
		"<!DOCTYPE[^>]+>" => mk(lexer,Comment(lexer.current)),
		"</"+attr+ ">" => mk(lexer,EndNode(lexer.current.substr(2, lexer.current.length - 3))),
		"<!\\[[Cc][dD][aA][tT][aA]\\[" => mk(lexer,CDataBegin),
		dblDot,
		"[:$]" => mkData(lexer),
		"[^:$<>]+" => mkData(lexer),
	];

	static public var cdata = @:rule [
		macroRule,
		dblDot,
		"]]>" => mk(lexer, CDataEnd),
		"[:$\\]]" => mkData(lexer),
		"[^:$\\]]+" => mkData(lexer)
	];

	static public var attributes = @:rule [
		macroRule,
		"[ \r\t\n]+" => lexer.token(attributes),
		">" => mk(lexer,NodeContent(true)),
		"/>" => mk(lexer,NodeContent(false)),
		dblDot,
		attr => mk(lexer,Ident(lexer.current)),
		"=" => mk(lexer, Op(OpAssign)),
		"'" => mk(lexer, Quote(false)),
		"\"" => mk(lexer, Quote(true))
	];

	static public var attrvalue = @:rule [
		macroRule,
		dblDot,
		"'" => mk(lexer,Quote(false)),
		"\"" => mk(lexer,Quote(true)),
		"[:$]" => mkData(lexer),
		"[^'\"\r\n$:]+" => mkData(lexer)
	];

	static public var macros = @:rule [
		"," => mk(lexer, Comma),
		"(" => mk(lexer, ParentOpen),
		")" => mk(lexer, ParentClose),
		"{" => mk(lexer, BraceOpen),
		"}" => mk(lexer, BraceClose),
		macroRule,
		dblDot,
		"[:$]" => mkData(lexer),
		"[^:$,(){}<]+" => mkData(lexer),
		"<"+attr => mk(lexer,Node(lexer.current.substr(1)))
	];

	static public var comment = @:rule [
		"-->" => lexer.curPos(),
		"-" => {
			buf.add(lexer.current);
			lexer.token(comment);
		},
		"[^-]" => {
			buf.add(lexer.current);
			lexer.token(comment);
		}
	];

	static public var expr = @:rule [
		"." => mk(lexer, Dot ),
		"," => mk(lexer, Comma ),
		"(" => mk(lexer, ParentOpen ),
		")" => mk(lexer, ParentClose ),
		"{" => mk(lexer, BraceOpen ),
		"}" => mk(lexer, BraceClose ),
		"\\[" => mk(lexer, BracketOpen ),
		"]" => mk(lexer, BracketClose ),
		"\\?" => mk(lexer, Question),
		"==" => mk(lexer, Op(OpEq)),
		"=" => mk(lexer, Op(OpAssign)),
		"[-+*/&|^!<>%~]+=?" => {
			var op = ops.get(lexer.current);
			if (op != null)
				mk(lexer,Op(op));
			else {
				var op = unops.get(lexer.current);
				if (op != null)
					mk(lexer,Unop(op));
				else
					throw InvalidOp(lexer.current);
			}
		},
		spaces => lexer.token(expr),
		"0" => mkInt(lexer),
		"[1-9][0-9]*" => mkInt(lexer),
		"[0-9]+.[0-9]*" => mkFloat(lexer),
		".[0-9]+" => mkFloat(lexer),
		ident => mkIdent(lexer),
		"\"" => {
			buf = new StringBuf();
			var p1 = lexer.curPos();
			var p2 = lexer.token(string);
			{
				tok: String(buf.toString()),
				pos: hxparse.Lexer.posUnion(p1, p2)
			}
		},
		"'" => {
			buf = new StringBuf();
			var p1 = lexer.curPos();
			var p2 = lexer.token(string2);
			{
				tok: String(buf.toString()),
				pos: hxparse.Lexer.posUnion(p1, p2)
			}
		},
		dblDot,
		":" => mk(lexer, DoubleDot)
	];

	static public var string = @:rule [
		"\\\\\"" => {
			buf.add('"');
			lexer.token(string);
		},
		"\\\\\\\\" => {
			buf.add('\\');
			lexer.token(string);
		},
		"\\\\n" => {
			buf.add('\n');
			lexer.token(string);
		},
		"\\\\t" => {
			buf.add('\t');
			lexer.token(string);
		},
		"\\\\r" => {
			buf.add('\r');
			lexer.token(string);
		},
		"\\\\"  => throw InvalidEscape,
		"\""  => lexer.curPos(),
		"[^\"\\\\]+" => {
			buf.add(lexer.current);
			lexer.token(string);
		}
	];

	static public var string2 = @:rule [
		"\\\\'" => {
			buf.add('\'');
			lexer.token(string2);
		},
		"\\\\\\\\" => {
			buf.add('\\');
			lexer.token(string2);
		},
		"\\\\n" => {
			buf.add('\n');
			lexer.token(string2);
		},
		"\\\\t" => {
			buf.add('\t');
			lexer.token(string2);
		},
		"\\\\r" => {
			buf.add('\r');
			lexer.token(string2);
		},
		"\\\\"  => throw InvalidEscape,
		"'"  => lexer.curPos(),
		"[^'\\\\]+" => {
			buf.add(lexer.current);
			lexer.token(string2);
		}
	];
}
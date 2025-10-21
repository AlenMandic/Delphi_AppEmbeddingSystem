unit Unit2;

interface

uses
Vcl.StdCtrls;

type
TLogHandler = procedure(const msg: String) of object; // Our main type of procedure-logic for our Logger.

procedure Logger(const msg: String); // Main Logger procedure. Sends the message to the subscriber.
procedure SetLogHandler(AHandler: TLogHandler); // Sets variable AHandler: TLogHandler to whoever wants to subscribe

implementation

var
LogHandler: TLogHandler;

// Call the subscriber to output message. Subscriber here would be a Form1.Logger function which logs to a Form1 UI-element (memo).
procedure Logger(const msg: String);
begin
If Assigned(LogHandler) then
LogHandler(msg);
end;

// Set subscriber procedure to handle log outputting. SetLogHandler(Form1.Logger: TLogHandler);
procedure SetLogHandler(AHandler: TLogHandler);
begin
LogHandler := AHandler;
end;

end.
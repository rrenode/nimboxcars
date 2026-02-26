type
  # Wrapper Types
  String8* = string
  FString* = distinct string

converter toString*(s: FString): string {.inline.} =
  string(s)

converter toFString*(s: string): FString {.inline.} =
  FString(s)

proc `$`*(s: FString): string {.inline.} =
  string(s)

proc len*(s: FString): int {.inline.} =
  string(s).len

proc `==`*(a, b: FString): bool {.inline.} =
  string(a) == string(b)

proc `&`*(a: FString, b: string): FString {.inline.} =
  FString(string(a) & b)

proc `&`*(a: string, b: FString): FString {.inline.} =
  FString(a & string(b))

proc `&`*(a, b: FString): FString {.inline.} =
  FString(string(a) & string(b))
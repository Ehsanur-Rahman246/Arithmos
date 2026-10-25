// Package shared holds the one place for error codes and number formatting.
package shared

import (
	"errors"
	"fmt"
)

// The 14 error codes of spec §2.2.
const (
	InvalidExpression = "INVALID_EXPRESSION"
	InvalidNumber     = "INVALID_NUMBER"
	DivByZero         = "DIV_BY_ZERO"
	DomainError       = "DOMAIN_ERROR"
	Undefined         = "UNDEFINED"
	Overflow          = "OVERFLOW"
	InvalidDigit      = "INVALID_DIGIT"
	InvalidBase       = "INVALID_BASE"
	OutOfRange        = "OUT_OF_RANGE"
	InvalidShift      = "INVALID_SHIFT"
	UnknownUnit       = "UNKNOWN_UNIT"
	IncompatibleUnits = "INCOMPATIBLE_UNITS"
	BelowAbsoluteZero = "BELOW_ABSOLUTE_ZERO"
	UnknownCommand    = "UNKNOWN_COMMAND"
)

// Error carries a spec error code and a human-readable message.
// Tests assert the Code, never the Message.
type Error struct {
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Message }

// Errf builds an *Error.
func Errf(code, format string, a ...any) *Error {
	return &Error{Code: code, Message: fmt.Sprintf(format, a...)}
}

// Throw panics with an *Error. Engines use it internally to keep code linear;
// every public engine function wraps its body in Guard, so callers get a
// normal returned error and never see the panic.
func Throw(code, format string, a ...any) {
	panic(Errf(code, format, a...))
}

// Guard runs f and turns a thrown *Error into a returned error.
// Any other panic is a real bug and propagates (the CLI reports it as INTERNAL).
func Guard(f func()) (err error) {
	defer func() {
		if r := recover(); r != nil {
			if e, ok := r.(*Error); ok {
				err = e
				return
			}
			panic(r)
		}
	}()
	f()
	return nil
}

// CodeOf returns the spec error code carried by err, or "".
func CodeOf(err error) string {
	var e *Error
	if errors.As(err, &e) {
		return e.Code
	}
	return ""
}
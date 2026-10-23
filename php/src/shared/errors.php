<?php
declare(strict_types=1);

namespace Arithmos\Shared;

/**
 * The only exception engines raise on purpose. It carries one of the 14 codes
 * from spec §2.2. Engines never print; only the CLI turns this into
 * "Error [CODE]: message". Tests assert errorCode(), never the message.
 */
final class ArithmosError extends \Exception
{
    public const INVALID_EXPRESSION = 'INVALID_EXPRESSION';
    public const INVALID_NUMBER = 'INVALID_NUMBER';
    public const DIV_BY_ZERO = 'DIV_BY_ZERO';
    public const DOMAIN_ERROR = 'DOMAIN_ERROR';
    public const UNDEFINED = 'UNDEFINED';
    public const OVERFLOW = 'OVERFLOW';
    public const INVALID_DIGIT = 'INVALID_DIGIT';
    public const INVALID_BASE = 'INVALID_BASE';
    public const OUT_OF_RANGE = 'OUT_OF_RANGE';
    public const INVALID_SHIFT = 'INVALID_SHIFT';
    public const UNKNOWN_UNIT = 'UNKNOWN_UNIT';
    public const INCOMPATIBLE_UNITS = 'INCOMPATIBLE_UNITS';
    public const BELOW_ABSOLUTE_ZERO = 'BELOW_ABSOLUTE_ZERO';
    public const UNKNOWN_COMMAND = 'UNKNOWN_COMMAND';

    private string $errorCode;

    public function __construct(string $errorCode, string $message)
    {
        parent::__construct($message);
        $this->errorCode = $errorCode;
    }

    /** The spec §2.2 code (Exception::getCode() is an int, so we keep our own). */
    public function errorCode(): string
    {
        return $this->errorCode;
    }

    /** The one-line form every edition prints. */
    public function render(): string
    {
        return 'Error [' . $this->errorCode . ']: ' . $this->getMessage();
    }
}
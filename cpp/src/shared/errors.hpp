// The one error type. Engines throw it; only the CLI turns it into
// "Error [CODE]: message". Codes are the 14 in spec §2.2.
#pragma once
#include <stdexcept>
#include <string>
#include <utility>

namespace arithmos {

class ArithmosError : public std::runtime_error {
 public:
  ArithmosError(std::string code, const std::string& message)
      : std::runtime_error(message), code_(std::move(code)) {}
  const std::string& code() const { return code_; }

 private:
  std::string code_;
};

}  // namespace arithmos
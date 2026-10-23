// Standard Calculator engine (spec §3). Pure logic: no I/O.
#pragma once
#include <string>

namespace arithmos::calculator {

// Holds `ans`. It changes only after a fully successful evaluation (spec §3.1).
class Session {
 public:
  // Evaluate one expression. Throws ArithmosError on failure.
  double evaluate(const std::string& expression);
  double ans() const { return ans_; }

 private:
  double ans_ = 0.0;  // 0 before the first calculation
};

}  // namespace arithmos::calculator
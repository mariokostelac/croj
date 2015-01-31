#include <cstring>

int main() {
  int *a = new int[1<<31];
  memset(a, 0, 1<<31);
  return 0;
}

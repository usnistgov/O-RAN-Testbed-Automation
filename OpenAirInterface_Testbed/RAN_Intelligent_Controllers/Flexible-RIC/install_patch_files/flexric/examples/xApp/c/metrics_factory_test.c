#include "metrics_factory.h"
#include <assert.h>
#include <stdlib.h>

int main(void) {
  assert(ss_sinr_level_representative_db(0) == -23.5);
  assert(ss_sinr_level_representative_db(1) == -23.0);
  assert(ss_sinr_level_representative_db(127) == 40.0);

  if (ss_sinr_level_representative_db(0) != -23.5 || ss_sinr_level_representative_db(1) != -23.0 ||
      ss_sinr_level_representative_db(127) != 40.0)
    return EXIT_FAILURE;

  return EXIT_SUCCESS;
}

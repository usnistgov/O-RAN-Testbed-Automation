/*
 * SPDX-License-Identifier: LicenseRef-CSSL-1.0
 */

#include <gtest/gtest.h>
extern "C" {
#include "nr_common.h"
#include "common/utils/LOG/log.h"
}

TEST(nr_common, nr_timer) {
  NR_timer_t timer;
  nr_timer_setup(&timer, 10, 1);
  nr_timer_start(&timer);
  EXPECT_TRUE(nr_timer_is_active(&timer));
  EXPECT_FALSE(nr_timer_expired(&timer));
  for (auto i = 0; i < 10; i++) {
    nr_timer_tick(&timer);
  }
  EXPECT_FALSE(nr_timer_is_active(&timer));
  EXPECT_TRUE(nr_timer_expired(&timer));
}


int main(int argc, char **argv)
{
  logInit();
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}

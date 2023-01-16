/*
 * Copyright 2021 The CFU-Playground Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "models/MLP_32x32/MLP_32x32.h"

#include <stdio.h>

#include "menu.h"
#include "models/MLP_32x32/model_MLP_32x32.h"
#include "models/MLP_32x32/image_data.h"
#include "tflite.h"

extern "C" {
#include "fb_util.h"
};

// Initialize everything once
// deallocate tensors when done
static void MLP_32x32_init(void) {
  tflite_load_model(model_MLP_32x32, model_MLP_32x32_len);
}

// Run classification, after input has been loaded
static int32_t MLP_32x32_classify() {
  printf("Running MLP_32x32\n");
  tflite_classify();

  // Process the inference results.
  int8_t* output = tflite_get_output();
  return output[1] - output[0];
}

static void do_classify_zeros() {
  tflite_set_input_zeros();
  int32_t result = MLP_32x32_classify();
  printf("  result is %ld\n", result);
}

static void do_classify() {
  tflite_set_input(MLP_32x32_data);
  int32_t result = MLP_32x32_classify();
  printf("  result is %ld\n", result);
}

#define NUM_GOLDEN 2
static int32_t golden_results[NUM_GOLDEN] = {-193, -175};

static void do_golden_tests() {
  int32_t actual[NUM_GOLDEN];

  tflite_set_input_zeros();
  actual[0] = MLP_32x32_classify();
  
  tflite_set_input(MLP_32x32_data);
  actual[1] = MLP_32x32_classify();

  bool failed = false;
  for (size_t i = 0; i < NUM_GOLDEN; i++) {
    if (actual[i] != golden_results[i]) {
      failed = true;
      printf("*** Golden test %d failed: %ld (actual) != %ld (expected))\n", i,
             actual[i], golden_results[i]);
    }
  }

  if (failed) {
    puts("FAIL Golden tests failed");
  } else {
    puts("OK   Golden tests passed");
  }
}

static struct Menu MENU = {
    "Tests for MLP_32x32 model",
    "test",
    {
        MENU_ITEM('1', "Run with zeros input", do_classify_zeros),
        MENU_ITEM('2', "Run with random input", do_classify),
        MENU_ITEM('g', "Run golden tests (check for expected outputs)",
                  do_golden_tests),
        MENU_END,
    },
};

// For integration into menu system
void MLP_32x32_menu() {
  MLP_32x32_init();
  
  menu_run(&MENU);
}

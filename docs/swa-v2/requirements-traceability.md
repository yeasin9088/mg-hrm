# SWA V2 — Rulebook v1.1 requirement traceability

Source: attached **MG_HRM_Smart_Work_Assistant_Rulebook_v1_1(1).md**, 385 BR rules and 69 AT checks.

**Status semantics:** Foundation = core logic exists with a synthetic test; Partial = part implemented but full acceptance not met; Not yet = not delivered. None is represented as production accepted without evidence.

## Business rule matrix

| Rule | Status | Code or database mapping | Test/evidence or gap |
|---|---|---|---|
| BR-001 | Partial | swa_work_items, sync_todo | scripts/swa-ci-assertions.sql |
| BR-002 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-003 | Partial | swa-model.js dueRisk independent of read state | tests/swa-model.test.cjs |
| BR-004 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-005 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-006 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-007 | Partial | swa_act separate milestones | scripts/swa-ci-assertions.sql |
| BR-008 | Partial | swa_act manual decision | scripts/swa-ci-assertions.sql |
| BR-009 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-010 | Partial | RLS and row_version | scripts/swa-ci-assertions.sql |
| BR-011 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-012 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-013 | Foundation | swa_private.operator_ids | scripts/swa-ci-assertions.sql |
| BR-014 | Foundation | swa_private.operator_ids and external requestor | scripts/swa-ci-assertions.sql |
| BR-015 | Partial | manager_channel + manually recorded audit | scripts/swa-ci-assertions.sql |
| BR-016 | Foundation | new functions cannot change HR source records | scripts/swa-ci-assertions.sql |
| BR-017 | Partial | swa-model.js Asia/Dhaka office candidate | tests/swa-model.test.cjs |
| BR-018 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-019 | Partial | swa-ui.js work cards | Manual Android review pending |
| BR-020 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-021 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-022 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-023 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-024 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-025 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-026 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-027 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-028 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-029 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-030 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-031 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-032 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-033 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-034 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-035 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-036 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-037 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-038 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-039 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-040 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-041 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-042 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-043 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-044 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-045 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-046 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-047 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-048 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-049 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-050 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-051 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-052 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-053 | Foundation | swa_capture default captured/waiting manager | scripts/swa-ci-assertions.sql |
| BR-054 | Foundation | swa_act informed/decision separation | scripts/swa-ci-assertions.sql |
| BR-055 | Foundation | swa_act informed | scripts/swa-ci-assertions.sql |
| BR-056 | Foundation | swa_act completion guard | scripts/swa-ci-assertions.sql |
| BR-057 | Foundation | swa_act communication_required | tests/swa-model.test.cjs |
| BR-058 | Partial | swa_act waiting_external | Manual review pending |
| BR-059 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-060 | Partial | swa_work_items blocked stage | Not automated |
| BR-061 | Partial | swa_act complete timestamp | scripts/swa-ci-assertions.sql |
| BR-062 | Foundation | swa_act reopen audit | scripts/swa-ci-assertions.sql |
| BR-063 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-064 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-065 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-066 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-067 | Partial | SWA separate read-blind policy | tests/swa-model.test.cjs |
| BR-068 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-069 | Foundation | swa_act ack | Not tested |
| BR-070 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-071 | Partial | swa-model.js dueRisk | tests/swa-model.test.cjs |
| BR-072 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-073 | Partial | promised_at distinct | tests/swa-model.test.cjs |
| BR-074 | Partial | swa_act snooze and dueRisk | tests/swa-model.test.cjs |
| BR-075 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-076 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-077 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-078 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-079 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-080 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-081 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-082 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-083 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-084 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-085 | Foundation | swa_work_items event_at | Not tested |
| BR-086 | Foundation | swa_work_items deadline_at | tests/swa-model.test.cjs |
| BR-087 | Foundation | swa_work_items promised_at | Not tested |
| BR-088 | Foundation | swa_work_items next_review_at | Not tested |
| BR-089 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-090 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-091 | Partial | Asia/Dhaka model formatting; DB timestamptz | tests/swa-model.test.cjs |
| BR-092 | Partial | swa_preferences; calendar unverified | tests/swa-model.test.cjs |
| BR-093 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-094 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-095 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-096 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-097 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-098 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-099 | Foundation | SWA work ledger distinct from notification delivery | Not end-to-end |
| BR-100 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-101 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-102 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-103 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-104 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-105 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-106 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-107 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-108 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-109 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-110 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-111 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-112 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-113 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-114 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-115 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-116 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-117 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-118 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-119 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-120 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-121 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-122 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-123 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-124 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-125 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-126 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-127 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-128 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-129 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-130 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-131 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-132 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-133 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-134 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-135 | Partial | swa-ui.js manager view anytime | Manual review pending |
| BR-136 | Partial | swa-ui.js Brief Manager Now | Manual review pending |
| BR-137 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-138 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-139 | Partial | swa_act manager actions | scripts/swa-ci-assertions.sql |
| BR-140 | Partial | swa_work_events channel and timestamps | scripts/swa-ci-assertions.sql |
| BR-141 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-142 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-143 | Partial | swa_brief_sessions and per-item event | Manual review pending |
| BR-144 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-145 | Partial | swa_brief_sessions | Not tested |
| BR-146 | Partial | swa-ui.js manually recorded wording | Manual review pending |
| BR-147 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-148 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-149 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-150 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-151 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-152 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-153 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-154 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-155 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-156 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-157 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-158 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-159 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-160 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-161 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-162 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-163 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-164 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-165 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-166 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-167 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-168 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-169 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-170 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-171 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-172 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-173 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-174 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-175 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-176 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-177 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-178 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-179 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-180 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-181 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-182 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-183 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-184 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-185 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-186 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-187 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-188 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-189 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-190 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-191 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-192 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-193 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-194 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-195 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-196 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-197 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-198 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-199 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-200 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-201 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-202 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-203 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-204 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-205 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-206 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-207 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-208 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-209 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-210 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-211 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-212 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-213 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-214 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-215 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-216 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-217 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-218 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-219 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-220 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-221 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-222 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-223 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-224 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-225 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-226 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-227 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-228 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-229 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-230 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-231 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-232 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-233 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-234 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-235 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-236 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-237 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-238 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-239 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-240 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-241 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-242 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-243 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-244 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-245 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-246 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-247 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-248 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-249 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-250 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-251 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-252 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-253 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-254 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-255 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-256 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-257 | Partial | database rows/version; UI refresh | Test needs multi-device |
| BR-258 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-259 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-260 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-261 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-262 | Foundation | swa_act expected row_version | scripts/swa-ci-assertions.sql |
| BR-263 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-264 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-265 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-266 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-267 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-268 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-269 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-270 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-271 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-272 | Partial | operator RLS RPC grants | scripts/swa-ci-assertions.sql |
| BR-273 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-274 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-275 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-276 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-277 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-278 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-279 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-280 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-281 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-282 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-283 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-284 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-285 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-286 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-287 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-288 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-289 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-290 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-291 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-292 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-293 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-294 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-295 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-296 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-297 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-298 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-299 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-300 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-301 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-302 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-303 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-304 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-305 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-306 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-307 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-308 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-309 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-310 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-311 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-312 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-313 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-314 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-315 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-316 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-317 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-318 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-319 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-320 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-321 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-322 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-323 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-324 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-325 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-326 | Partial | swa-model officeTime | tests/swa-model.test.cjs |
| BR-327 | Partial | swa_capture vs executed state | scripts/swa-ci-assertions.sql |
| BR-328 | Partial | swa-ui.js capture always accessible | Manual review pending |
| BR-329 | Foundation | swa_capture independent status | scripts/swa-ci-assertions.sql |
| BR-330 | Partial | actual deadline preserved | tests/swa-model.test.cjs |
| BR-331 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-332 | Partial | manager decision logging nighttime | Manual review pending |
| BR-333 | Partial | swa_act execution still pending | scripts/swa-ci-assertions.sql |
| BR-334 | Partial | unverified workday label | tests/swa-model.test.cjs |
| BR-335 | Partial | UTC timestamptz / Dhaka model | tests/swa-model.test.cjs |
| BR-336 | Partial | swa_capture captured_after_hours | Not end-to-end |
| BR-337 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-338 | Partial | event_at vs captured_at | Not end-to-end |
| BR-339 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-340 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-341 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-342 | Partial | swa-model.js dueRisk | tests/swa-model.test.cjs |
| BR-343 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-344 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-345 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-346 | Partial | manager desk independent of officeTime | Manual review pending |
| BR-347 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-348 | Partial | swa_act separate decision/informed | scripts/swa-ci-assertions.sql |
| BR-349 | Partial | swa_brief_sessions | Manual review pending |
| BR-350 | Partial | manager_decision_at/recorded_at | Not end-to-end |
| BR-351 | Partial | UI manual decision notice | Manual review pending |
| BR-352 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-353 | Partial | swa_act communicated timestamp | scripts/swa-ci-assertions.sql |
| BR-354 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-355 | Partial | swa_act decision doesn't complete | scripts/swa-ci-assertions.sql |
| BR-356 | Partial | swa-ui.css responsive | Android real device pending |
| BR-357 | Partial | 4 time fields | Not end-to-end |
| BR-358 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-359 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-360 | Partial | dueRisk before_office_risk | tests/swa-model.test.cjs |
| BR-361 | Partial | nextOfficeCandidate not altering deadline | tests/swa-model.test.cjs |
| BR-362 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-363 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-364 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-365 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-366 | Not active | swa_preferences; V2 push disabled | Requires engine rollout |
| BR-367 | Partial | swa_preferences digest fields | Missing digest scheduler |
| BR-368 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-369 | Foundation | read-blind SWA policy | tests/swa-model.test.cjs |
| BR-370 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-371 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-372 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-373 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-374 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-375 | Partial | work list source independent of push | Manual testing pending |
| BR-376 | Partial | swa-ui.js quick capture | Mobile UX pending |
| BR-377 | Partial | swa_ui save validation, conflict reload | Offline reconciliation pending |
| BR-378 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-379 | Partial | swa-model.js outstanding state | tests/swa-model.test.cjs |
| BR-380 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-381 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-382 | Partial | swa_act execution logging unrestricted by office | Test needed |
| BR-383 | Foundation | SWA no HR-source mutation | scripts/swa-ci-assertions.sql |
| BR-384 | Not yet | No verified implementation | Backlog: design, integration and/or tests missing |
| BR-385 | Foundation | explain limitations | docs/swa-v2/release-status.md |

## Acceptance tests

| Test | Status | Evidence / missing validation |
|---|---|---|
| AT-001 | Partial / synthetic | Capture key idempotency tested in SQL; offline queue missing |
| AT-002 | Partial / synthetic | Open todo mirror next action; no action-less classification |
| AT-003 | Partial / synthetic | Read-blind policy unit test; V1 remains |
| AT-004 | Partial / synthetic | Manager informed separate in SQL test |
| AT-005 | Partial / synthetic | Manager approval not auto-execute in SQL test |
| AT-006 | Partial / synthetic | Communication step retained in model; rejection SQL test pending |
| AT-007 | Partial / synthetic | Completion guard in SQL test |
| AT-008 | Partial / synthetic | Reopen audit in SQL test |
| AT-009 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-010 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-011 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-012 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-013 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-014 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-015 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-016 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-017 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-018 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-019 | Partial / synthetic | Existing transfer code untouched; full regression pending |
| AT-020 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-021 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-022 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-023 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-024 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-025 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-026 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-027 | Partial / synthetic | Source identity separate by todo ID; two-request test missing |
| AT-028 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-029 | Partial / synthetic | SWA event identity uniqueness; concurrent job test missing |
| AT-030 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-031 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-032 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-033 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-034 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-035 | Partial / synthetic | Dhaka clock unit tested; timestamps persisted UTC |
| AT-036 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-037 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-038 | Partial / synthetic | SWA RLS unauthorized user synthetic SQL test |
| AT-039 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-040 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-041 | Partial / synthetic | Todo backfill synthetic SQL test; live migration pending |
| AT-042 | Partial / synthetic | Flag off, additive rollback; future switching test missing |
| AT-043 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-044 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-045 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-046 | Partial / synthetic | SWA does not send messages or approve source records |
| AT-047 | Partial / synthetic | Capture after-hours logic; real DB boundary test missing |
| AT-048 | Partial / synthetic | Manager Desk 24h UI, pending in-app smoke |
| AT-049 | Partial / synthetic | Manager decision cannot complete office steps |
| AT-050 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-051 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-052 | Partial / synthetic | Before-office risk unit test |
| AT-053 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-054 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-055 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-056 | Partial / synthetic | Read blind unit test |
| AT-057 | Partial / synthetic | Manager milestone distinct state |
| AT-058 | Partial / synthetic | Deadline risk unit test |
| AT-059 | Partial / synthetic | Calendar explicitly unverified |
| AT-060 | Partial / synthetic | Dhaka 09/18 synthetic tests |
| AT-061 | Partial / synthetic | Row version CAS synthetic SQL test |
| AT-062 | Partial / synthetic | Failed save UX; offline draft queue missing |
| AT-063 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-064 | Partial / synthetic | Snooze overdue unit test |
| AT-065 | Partial / synthetic | Actual event and recorded_at separated, test pending |
| AT-066 | Partial / synthetic | Overdue remains regardless office hour |
| AT-067 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
| AT-068 | Partial / synthetic | Push independent Action Queue; health warning missing |
| AT-069 | Not verified | Not verified: required production-equivalent synthetic/real-device test missing |
# HAR sanitizer report

- HAR entries: 8
- instagram.com JSON requests kept: 8
- other instagram.com non-JSON responses skipped: 0
- JSON responses with no body in the HAR: 0
- JSON responses that did not parse: 0

## Candidate requests (TECH_SPEC 4.1)

| ID | Purpose | Candidate | Seen | Request #s | Status |
|----|---------|-----------|------|------------|--------|
| IG-1 | Username -> user (add, refresh) | `GET /api/v1/users/web_profile_info/?username={u}` | no | - | - |
| IG-2 | Stories for up to 20 users | `GET /api/v1/feed/reels_media/?reel_ids={id}&reel_ids=...` | no | - | - |
| IG-3 | User by ID | `GET i.instagram.com/api/v1/users/{id}/info/` | no | - | - |
| IG-4 | Validate session | `GET /api/v1/accounts/current_user/?edit=true` | no | - | - |
| IG-5 | Latest posts of a user | `GET /api/v1/feed/user/{id}/?count=12` | no | - | - |

## Unknown JSON requests (not IG-1..IG-5)

| # | Method | Host | Path | Query keys | Status | Size | Media fields |
|---|--------|------|------|------------|--------|------|--------------|
| 1 | POST | www.instagram.com | `/ajax/<seg>/` |  | 200 | 3258 |  |
| 2 | GET | www.instagram.com | `/ajax/<seg>/` | <name>, __d, __a | 200 | 36465 |  |
| 3 | POST | www.instagram.com | `/api/graphql` |  | 200 | 21405 | image_versions2, media_type, taken_at, has_audio, carousel_media, dash_manifest, video_versions, product_type, video_duration, expiring_at |
| 4 | POST | www.instagram.com | `/api/graphql` |  | 200 | 280 |  |
| 5 | POST | www.instagram.com | `/ajax/bulk-route-definitions/` |  | 200 | 3331 |  |
| 6 | POST | www.instagram.com | `/api/graphql` |  | 200 | 196 |  |
| 7 | POST | www.instagram.com | `/ajax/<seg>` | __a, <name>, __d | 200 | 94 |  |
| 8 | POST | www.instagram.com | `/api/graphql` |  | 200 | 17445 |  |

## Auto-detected media fields

| Field | JSON path (`[]` = array, `*` = ID key) | Count | Request #s | Types | Distinct values |
|-------|----------------------------------------|-------|------------|-------|-----------------|
| carousel_media | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].carousel_media` | 1 | 3 | null |  |
| dash_manifest | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].video_dash_manifest` | 1 | 3 | string |  |
| expiring_at | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].expiring_at` | 1 | 3 | int |  |
| has_audio | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].has_audio` | 1 | 3 | bool | true |
| image_versions2 | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].image_versions2` | 1 | 3 | object |  |
| media_type | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].media_type` | 1 | 3 | int | 2 |
| product_type | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349[].product_type` | 1 | 3 | string | feed |
| product_type | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].product_type` | 1 | 3 | string | story |
| taken_at | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].taken_at` | 1 | 3 | int |  |
| video_duration | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].video_duration` | 1 | 3 | int |  |
| video_versions | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].video_versions` | 1 | 3 | array |  |

## HTML documents on instagram.com

Pages can embed their data in the HTML instead of a JSON request. Only marker names are listed; no HTML is copied.

None in this HAR.

## ID field types (original JSON types)

| Key | Original type(s) |
|-----|------------------|
| `` | int |
| `id` | digit-string, compound-string |
| `pk` | digit-string |
| `user_id` | digit-string |

In the sanitized bodies, string IDs became `user_N` / `media_N`; integer IDs became integers (user 7000000000+N, media 8000000000+N).

## Replaced object keys (never the original names)

Decide what to add to `tool/keep_keys.txt` by the path and count: open the same response in the Instagram web devtools on your own machine and check whether that position is a schema field or a name. Only schema field names may be added.

| Placeholder | Count | In dynamic map | Seen at (max 5) |
|-------------|-------|----------------|-----------------|
| key_1 | 4 | no | `$.key_1` x3, `$.key_1.key_1` x1 |
| key_2 | 2 | no | `$.key_1.key_1.key_2` x1, `$.key_1.key_407.key_408.key_2` x1 |
| key_3 | 21 | no | `$.key_1.key_1.key_3` x1, `$.key_70.key_53.key_71.key_89.key_90.key_3` x1, `$.key_70.key_53.key_71.key_89.key_92.key_3` x1, `$.key_70.key_53.key_71.key_89.key_93.key_3` x1, `$.key_70.key_53.key_71.key_89.key_94.key_3` x1 |
| key_4 | 2 | no | `$.key_1.key_1.key_3.key_4` x1, `$.key_1.key_407.key_408.key_3.key_4` x1 |
| key_5 | 2 | no | `$.key_1.key_1.key_3.key_4.key_5` x1, `$.key_1.key_407.key_408.key_3.key_4.key_5` x1 |
| key_6 | 2 | no | `$.key_1.key_1.key_3.key_4.key_6` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6` x1 |
| key_7 | 7 | no | `$.key_1.key_1.key_3.key_4.key_6.key_7` x1, `$.key_1.key_1.key_3.key_4.key_29.key_7` x1, `$.key_1.key_52.key_7` x2, `$.key_70.key_7` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_7` x1 |
| key_8 | 16 | no | `$.key_1.key_1.key_3.key_4.key_6.key_7[].key_8` x2, `$.key_1.key_1.key_3.key_4.key_6.key_9.key_8` x1, `$.key_1.key_1.key_3.key_4.key_29.key_7[].key_8` x2, `$.key_1.key_1.key_3.key_4.key_29.key_9.key_8` x1, `$.key_1.key_52.key_61.key_62[][][][].key_8` x4 |
| key_9 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_9` x1, `$.key_1.key_1.key_3.key_4.key_29.key_9` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_9` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_9` x1 |
| key_10 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10` x1 |
| key_11 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10.key_11` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10.key_11` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10.key_11` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10.key_11` x1 |
| key_12 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10.key_11.key_12` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10.key_11.key_12` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10.key_11.key_12` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10.key_11.key_12` x1 |
| key_13 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10.key_11.key_13` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10.key_11.key_13` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10.key_11.key_13` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10.key_11.key_13` x1 |
| key_14 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10.key_11.key_13.key_14` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10.key_11.key_13.key_14` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10.key_11.key_13.key_14` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10.key_11.key_13.key_14` x1 |
| key_15 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_10.key_15` x1, `$.key_1.key_1.key_3.key_4.key_29.key_10.key_15` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_10.key_15` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_10.key_15` x1 |
| key_16 | 4 | no | `$.key_1.key_1.key_3.key_4.key_6.key_16` x1, `$.key_1.key_1.key_3.key_4.key_29.key_16` x1, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_16` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_16` x1 |
| key_17 | 8 | no | `$.key_1.key_1.key_3.key_4.key_6.key_16.key_17` x1, `$.key_1.key_1.key_3.key_4.key_29.key_16.key_17` x1, `$.key_1.key_52.key_61.key_62[][][][].key_17` x4, `$.key_1.key_407.key_408.key_3.key_4.key_6.key_16.key_17` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29.key_16.key_17` x1 |
| key_18 | 2 | no | `$.key_1.key_1.key_3.key_4.key_18` x1, `$.key_1.key_407.key_408.key_3.key_4.key_18` x1 |
| key_19 | 2 | no | `$.key_1.key_1.key_3.key_4.key_19` x1, `$.key_1.key_407.key_408.key_3.key_4.key_19` x1 |
| key_20 | 4 | no | `$.key_1.key_1.key_3.key_4.key_19.key_20` x1, `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338[].key_339.key_20` x1, `$.data.xdt_api__v1__feed__reels_media.reels_media[].key_20` x1, `$.key_1.key_407.key_408.key_3.key_4.key_19.key_20` x1 |
| key_21 | 2 | no | `$.key_1.key_1.key_3.key_4.key_19.key_21` x1, `$.key_1.key_407.key_408.key_3.key_4.key_19.key_21` x1 |
| key_22 | 2 | no | `$.key_1.key_1.key_3.key_4.key_19.key_22` x1, `$.key_1.key_407.key_408.key_3.key_4.key_19.key_22` x1 |
| key_23 | 2 | no | `$.key_1.key_1.key_3.key_4.key_23` x1, `$.key_1.key_407.key_408.key_3.key_4.key_23` x1 |
| key_24 | 2 | no | `$.key_1.key_1.key_3.key_4.key_24` x1, `$.key_1.key_407.key_408.key_3.key_4.key_24` x1 |
| key_25 | 2 | no | `$.key_1.key_1.key_3.key_4.key_25` x1, `$.key_1.key_407.key_408.key_3.key_4.key_25` x1 |
| key_26 | 2 | no | `$.key_1.key_1.key_3.key_4.key_25.key_26` x1, `$.key_1.key_407.key_408.key_3.key_4.key_25.key_26` x1 |
| key_27 | 2 | yes | `$.key_1.key_1.key_3.key_4.key_25.key_26.key_27` x1, `$.key_1.key_407.key_408.key_3.key_4.key_25.key_26.key_27` x1 |
| key_28 | 3 | yes | `$.key_1.key_1.key_3.key_4.key_25.key_26.key_28` x1, `$.key_70.key_53.key_71.key_98.key_99.key_28` x1, `$.key_1.key_407.key_408.key_3.key_4.key_25.key_26.key_28` x1 |
| key_29 | 2 | no | `$.key_1.key_1.key_3.key_4.key_29` x1, `$.key_1.key_407.key_408.key_3.key_4.key_29` x1 |
| key_30 | 2 | no | `$.key_1.key_1.key_3.key_4.key_30` x1, `$.key_1.key_407.key_408.key_3.key_4.key_30` x1 |
| key_31 | 2 | no | `$.key_1.key_1.key_3.key_4.key_31` x1, `$.key_1.key_407.key_408.key_3.key_4.key_31` x1 |
| key_32 | 2 | no | `$.key_1.key_1.key_3.key_4.key_32` x1, `$.key_1.key_407.key_408.key_3.key_4.key_32` x1 |
| key_33 | 2 | no | `$.key_1.key_1.key_3.key_4.key_33` x1, `$.key_1.key_407.key_408.key_3.key_4.key_33` x1 |
| key_34 | 2 | no | `$.key_1.key_1.key_3.key_4.key_34` x1, `$.key_1.key_407.key_408.key_3.key_4.key_34` x1 |
| key_35 | 2 | no | `$.key_1.key_1.key_3.key_4.key_35` x1, `$.key_1.key_407.key_408.key_3.key_4.key_35` x1 |
| key_36 | 2 | no | `$.key_1.key_1.key_3.key_4.key_36` x1, `$.key_1.key_407.key_408.key_3.key_4.key_36` x1 |
| key_37 | 2 | no | `$.key_1.key_1.key_3.key_4.key_36.key_37` x1, `$.key_1.key_407.key_408.key_3.key_4.key_36.key_37` x1 |
| key_38 | 2 | no | `$.key_1.key_1.key_3.key_4.key_38` x1, `$.key_1.key_407.key_408.key_3.key_4.key_38` x1 |
| key_39 | 2 | no | `$.key_1.key_1.key_3.key_39` x1, `$.key_1.key_407.key_408.key_3.key_39` x1 |
| key_40 | 4 | no | `$.key_1.key_1.key_3.key_39[].key_40` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_40` x2 |
| key_41 | 8 | yes | `$.key_1.key_1.key_3.key_39[].key_40.key_41` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_41` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_40.key_41` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_41` x2 |
| key_42 | 177 | yes | `$.key_1.key_1.key_3.key_39[].key_40.key_42` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_42` x1, `$.key_1.key_52.key_63.key_42` x2, `$.key_70.key_53.key_71.key_74.key_75.key_42` x1, `$.key_70.key_53.key_71.key_74.key_76.key_42` x1 |
| key_43 | 4 | no | `$.key_1.key_1.key_3.key_39[].key_43` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_43` x2 |
| key_44 | 4 | no | `$.key_1.key_1.key_3.key_39[].key_44` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_44` x2 |
| key_45 | 2 | yes | `$.key_1.key_1.key_3.key_39[].key_44.key_45` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45` x1 |
| key_46 | 10 | no | `$.key_1.key_1.key_3.key_39[].key_44.key_45.key_46` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_41.key_46` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_42.key_46` x1, `$.key_1.key_1.key_3.key_39[].key_44.username.key_46` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45.key_46` x1 |
| key_47 | 10 | no | `$.key_1.key_1.key_3.key_39[].key_44.key_45.key_47` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_41.key_47` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_42.key_47` x1, `$.key_1.key_1.key_3.key_39[].key_44.username.key_47` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45.key_47` x1 |
| key_48 | 10 | no | `$.key_1.key_1.key_3.key_39[].key_44.key_45.key_48` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_41.key_48` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_42.key_48` x1, `$.key_1.key_1.key_3.key_39[].key_44.username.key_48` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45.key_48` x1 |
| key_49 | 10 | no | `$.key_1.key_1.key_3.key_39[].key_44.key_45.key_49` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_41.key_49` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_42.key_49` x1, `$.key_1.key_1.key_3.key_39[].key_44.username.key_49` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45.key_49` x1 |
| key_50 | 10 | no | `$.key_1.key_1.key_3.key_39[].key_44.key_45.key_50` x1, `$.key_1.key_1.key_3.key_39[].key_44.key_41.key_50` x2, `$.key_1.key_1.key_3.key_39[].key_44.key_42.key_50` x1, `$.key_1.key_1.key_3.key_39[].key_44.username.key_50` x1, `$.key_1.key_407.key_408.key_3.key_39[].key_44.key_45.key_50` x1 |
| key_51 | 4 | no | `$.key_1.key_1.key_3.key_39[].key_51` x2, `$.key_1.key_407.key_408.key_3.key_39[].key_51` x2 |
| key_52 | 2 | no | `$.key_1.key_52` x2 |
| key_53 | 3 | no | `$.key_1.key_52.key_53` x2, `$.key_70.key_53` x1 |
| key_54 | 3 | yes | `$.key_1.key_52.key_53.key_54` x2, `$.key_70.key_53.key_54` x1 |
| key_55 | 3 | yes | `$.key_1.key_52.key_53.key_54.key_55` x2, `$.key_70.key_53.key_54.key_55` x1 |
| key_56 | 3 | no | `$.key_1.key_52.key_53.key_54.key_55.key_56` x2, `$.key_70.key_53.key_54.key_55.key_56` x1 |
| key_57 | 3 | yes | `$.key_1.key_52.key_53.key_54.key_57` x2, `$.key_70.key_53.key_54.key_57` x1 |
| key_58 | 1 | no | `$.key_1.key_52.key_53.key_54.key_57.key_58` x1 |
| key_59 | 85 | no | `$.key_1.key_52.key_53.key_54.key_57.key_58.key_59` x1, `$.key_70.key_53.key_54.key_57.key_219.key_59` x1, `$.key_70.key_53.key_54.key_57.key_220.key_59` x1, `$.key_70.key_53.key_54.key_57.key_221.key_59` x1, `$.key_70.key_53.key_54.key_57.key_222.key_59` x1 |
| key_60 | 3 | yes | `$.key_1.key_52.key_53.key_54.key_60` x2, `$.key_70.key_53.key_54.key_60` x1 |
| key_61 | 3 | no | `$.key_1.key_52.key_61` x2, `$.key_70.key_61` x1 |
| key_62 | 3 | no | `$.key_1.key_52.key_61.key_62` x2, `$.key_70.key_61.key_62` x1 |
| key_63 | 3 | no | `$.key_1.key_52.key_63` x2, `$.key_70.key_63` x1 |
| key_64 | 18 | no | `$.key_1.key_52.key_63.key_64` x2, `$.key_70.key_53.key_54.key_304.key_307.key_64` x1, `$.key_70.key_53.key_54.key_304.key_308.key_64` x1, `$.key_70.key_53.key_54.key_304.key_309.key_64` x1, `$.key_70.key_53.key_54.key_304.key_311.key_64` x1 |
| key_65 | 26 | no | `$.key_1.key_52.key_63.key_65` x2, `$.key_70.key_53.key_54.key_304.key_305.key_65` x1, `$.key_70.key_53.key_54.key_304.key_307.key_65` x1, `$.key_70.key_53.key_54.key_304.key_308.key_65` x1, `$.key_70.key_53.key_54.key_304.key_309.key_65` x1 |
| key_66 | 2 | no | `$.key_1.key_66` x2 |
| key_67 | 1 | no | `$.key_1.key_67` x1 |
| key_68 | 2 | no | `$.key_68` x2 |
| key_69 | 2 | no | `$.key_69` x2 |
| key_70 | 1 | no | `$.key_70` x1 |
| key_71 | 1 | yes | `$.key_70.key_53.key_71` x1 |
| key_72 | 1 | yes | `$.key_70.key_53.key_71.key_72` x1 |
| key_73 | 2 | no | `$.key_70.key_53.key_71.key_72.*.key_73` x2 |
| key_74 | 1 | yes | `$.key_70.key_53.key_71.key_74` x1 |
| key_75 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_75` x1 |
| key_76 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_76` x1 |
| key_77 | 7 | yes | `$.key_70.key_53.key_71.key_74.key_76.key_77` x1, `$.key_70.key_53.key_71.key_74.key_83.key_77` x1, `$.key_70.key_53.key_71.key_74.key_84.key_77` x1, `$.key_70.key_53.key_71.key_74.key_85.key_77` x1, `$.key_70.key_53.key_71.key_74.key_86.key_77` x1 |
| key_78 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_78` x1 |
| key_79 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_79` x1 |
| key_80 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_80` x1 |
| key_81 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_81` x1 |
| key_82 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_82` x1 |
| key_83 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_83` x1 |
| key_84 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_84` x1 |
| key_85 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_85` x1 |
| key_86 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_86` x1 |
| key_87 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_87` x1 |
| key_88 | 1 | yes | `$.key_70.key_53.key_71.key_74.key_88` x1 |
| key_89 | 1 | yes | `$.key_70.key_53.key_71.key_89` x1 |
| key_90 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_90` x1 |
| key_91 | 19 | no | `$.key_70.key_53.key_71.key_89.key_90.key_91` x1, `$.key_70.key_53.key_71.key_89.key_92.key_91` x1, `$.key_70.key_53.key_71.key_89.key_93.key_91` x1, `$.key_70.key_53.key_71.key_89.key_94.key_91` x1, `$.key_70.key_53.key_71.key_89.key_95.key_91` x1 |
| key_92 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_92` x1 |
| key_93 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_93` x1 |
| key_94 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_94` x1 |
| key_95 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_95` x1 |
| key_96 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_96` x1 |
| key_97 | 1 | yes | `$.key_70.key_53.key_71.key_89.key_97` x1 |
| key_98 | 1 | yes | `$.key_70.key_53.key_71.key_98` x1 |
| key_99 | 1 | no | `$.key_70.key_53.key_71.key_98.key_99` x1 |
| key_100 | 1 | yes | `$.key_70.key_53.key_71.key_100` x1 |
| key_101 | 1 | yes | `$.key_70.key_53.key_71.key_100.key_101` x1 |
| key_102 | 3 | yes | `$.key_70.key_53.key_71.key_100.key_101.key_102` x1, `$.key_70.key_53.key_71.key_100.key_103.key_102` x1, `$.key_70.key_53.key_71.key_100.key_104.key_102` x1 |
| key_103 | 1 | yes | `$.key_70.key_53.key_71.key_100.key_103` x1 |
| key_104 | 1 | yes | `$.key_70.key_53.key_71.key_100.key_104` x1 |
| key_105 | 1 | yes | `$.key_70.key_53.key_71.key_105` x1 |
| key_106 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_106` x1 |
| key_107 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_107` x1 |
| key_108 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_108` x1 |
| key_109 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_109` x1 |
| key_110 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_110` x1 |
| key_111 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_111` x1 |
| key_112 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_112` x1 |
| key_113 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_113` x1 |
| key_114 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_114` x1 |
| key_115 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_115` x1 |
| key_116 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_116` x1 |
| key_117 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_117` x1 |
| key_118 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_118` x1 |
| key_119 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_119` x1 |
| key_120 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_120` x1 |
| key_121 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_121` x1 |
| key_122 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_122` x1 |
| key_123 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_123` x1 |
| key_124 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_124` x1 |
| key_125 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_125` x1 |
| key_126 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_126` x1 |
| key_127 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_127` x1 |
| key_128 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_128` x1 |
| key_129 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_129` x1 |
| key_130 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_130` x1 |
| key_131 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_131` x1 |
| key_132 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_132` x1 |
| key_133 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_133` x1 |
| key_134 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_134` x1 |
| key_135 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_135` x1 |
| key_136 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_136` x1 |
| key_137 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_137` x1 |
| key_138 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_138` x1 |
| key_139 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_139` x1 |
| key_140 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_140` x1 |
| key_141 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_141` x1 |
| key_142 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_142` x1 |
| key_143 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_143` x1 |
| key_144 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_144` x1 |
| key_145 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_145` x1 |
| key_146 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_146` x1 |
| key_147 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_147` x1 |
| key_148 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_148` x1 |
| key_149 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_149` x1 |
| key_150 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_150` x1 |
| key_151 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_151` x1 |
| key_152 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_152` x1 |
| key_153 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_153` x1 |
| key_154 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_154` x1 |
| key_155 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_155` x1 |
| key_156 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_156` x1 |
| key_157 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_157` x1 |
| key_158 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_158` x1 |
| key_159 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_159` x1 |
| key_160 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_160` x1 |
| key_161 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_161` x1 |
| key_162 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_162` x1 |
| key_163 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_163` x1 |
| key_164 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_164` x1 |
| key_165 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_165` x1 |
| key_166 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_166` x1 |
| key_167 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_167` x1 |
| key_168 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_168` x1 |
| key_169 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_169` x1 |
| key_170 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_170` x1 |
| key_171 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_171` x1 |
| key_172 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_172` x1 |
| key_173 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_173` x1 |
| key_174 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_174` x1 |
| key_175 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_175` x1 |
| key_176 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_176` x1 |
| key_177 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_177` x1 |
| key_178 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_178` x1 |
| key_179 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_179` x1 |
| key_180 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_180` x1 |
| key_181 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_181` x1 |
| key_182 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_182` x1 |
| key_183 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_183` x1 |
| key_184 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_184` x1 |
| key_185 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_185` x1 |
| key_186 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_186` x1 |
| key_187 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_187` x1 |
| key_188 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_188` x1 |
| key_189 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_189` x1 |
| key_190 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_190` x1 |
| key_191 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_191` x1 |
| key_192 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_192` x1 |
| key_193 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_193` x1 |
| key_194 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_194` x1 |
| key_195 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_195` x1 |
| key_196 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_196` x1 |
| key_197 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_197` x1 |
| key_198 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_198` x1 |
| key_199 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_199` x1 |
| key_200 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_200` x1 |
| key_201 | 1 | yes | `$.key_70.key_53.key_71.key_105.key_201` x1 |
| key_202 | 1 | yes | `$.key_70.key_53.key_71.key_202` x1 |
| key_203 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_203` x1 |
| key_204 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_204` x1 |
| key_205 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_205` x1 |
| key_206 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_206` x1 |
| key_207 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_207` x1 |
| key_208 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_208` x1 |
| key_209 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_209` x1 |
| key_210 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_210` x1 |
| key_211 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_211` x1 |
| key_212 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_212` x1 |
| key_213 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_213` x1 |
| key_214 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_214` x1 |
| key_215 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_215` x1 |
| key_216 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_216` x1 |
| key_217 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_217` x1 |
| key_218 | 1 | yes | `$.key_70.key_53.key_71.key_202.key_218` x1 |
| key_219 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_219` x1 |
| key_220 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_220` x1 |
| key_221 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_221` x1 |
| key_222 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_222` x1 |
| key_223 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_223` x1 |
| key_224 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_224` x1 |
| key_225 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_225` x1 |
| key_226 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_226` x1 |
| key_227 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_227` x1 |
| key_228 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_228` x1 |
| key_229 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_229` x1 |
| key_230 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_230` x1 |
| key_231 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_231` x1 |
| key_232 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_232` x1 |
| key_233 | 26 | no | `$.key_70.key_53.key_54.key_57.key_232.key_233` x1, `$.key_70.key_53.key_54.key_57.key_238.key_233` x1, `$.key_70.key_53.key_54.key_57.key_240.key_233` x1, `$.key_70.key_53.key_54.key_57.key_250.key_233` x1, `$.key_70.key_53.key_54.key_57.key_254.key_233` x1 |
| key_234 | 64 | no | `$.key_70.key_53.key_54.key_57.key_232.key_234` x1, `$.key_70.key_53.key_54.key_57.key_238.key_234` x1, `$.key_70.key_53.key_54.key_57.key_240.key_234` x1, `$.key_70.key_53.key_54.key_57.key_250.key_234` x1, `$.key_70.key_53.key_54.key_57.key_254.key_234` x1 |
| key_235 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_235` x1 |
| key_236 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_236` x1 |
| key_237 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_237` x1 |
| key_238 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_238` x1 |
| key_239 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_239` x1 |
| key_240 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_240` x1 |
| key_241 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_241` x1 |
| key_242 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_242` x1 |
| key_243 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_243` x1 |
| key_244 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_244` x1 |
| key_245 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_245` x1 |
| key_246 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_246` x1 |
| key_247 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_247` x1 |
| key_248 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_248` x1 |
| key_249 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_249` x1 |
| key_250 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_250` x1 |
| key_251 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_251` x1 |
| key_252 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_252` x1 |
| key_253 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_253` x1 |
| key_254 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_254` x1 |
| key_255 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_255` x1 |
| key_256 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_256` x1 |
| key_257 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_257` x1 |
| key_258 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_258` x1 |
| key_259 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_259` x1 |
| key_260 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_260` x1 |
| key_261 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_261` x1 |
| key_262 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_262` x1 |
| key_263 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_263` x1 |
| key_264 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_264` x1 |
| key_265 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_265` x1 |
| key_266 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_266` x1 |
| key_267 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_267` x1 |
| key_268 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_268` x1 |
| key_269 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_269` x1 |
| key_270 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_270` x1 |
| key_271 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_271` x1 |
| key_272 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_272` x1 |
| key_273 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_273` x1 |
| key_274 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_274` x1 |
| key_275 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_275` x1 |
| key_276 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_276` x1 |
| key_277 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_277` x1 |
| key_278 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_278` x1 |
| key_279 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_279` x1 |
| key_280 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_280` x1 |
| key_281 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_281` x1 |
| key_282 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_282` x1 |
| key_283 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_283` x1 |
| key_284 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_284` x1 |
| key_285 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_285` x1 |
| key_286 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_286` x1 |
| key_287 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_287` x1 |
| key_288 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_288` x1 |
| key_289 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_289` x1 |
| key_290 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_290` x1 |
| key_291 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_291` x1 |
| key_292 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_292` x1 |
| key_293 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_293` x1 |
| key_294 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_294` x1 |
| key_295 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_295` x1 |
| key_296 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_296` x1 |
| key_297 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_297` x1 |
| key_298 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_298` x1 |
| key_299 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_299` x1 |
| key_300 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_300` x1 |
| key_301 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_301` x1 |
| key_302 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_302` x1 |
| key_303 | 1 | yes | `$.key_70.key_53.key_54.key_57.key_303` x1 |
| key_304 | 1 | yes | `$.key_70.key_53.key_54.key_304` x1 |
| key_305 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_305` x1 |
| key_306 | 25 | no | `$.key_70.key_53.key_54.key_304.key_305.key_306` x1, `$.key_70.key_53.key_54.key_304.key_307.key_306` x1, `$.key_70.key_53.key_54.key_304.key_308.key_306` x1, `$.key_70.key_53.key_54.key_304.key_309.key_306` x1, `$.key_70.key_53.key_54.key_304.key_310.key_306` x1 |
| key_307 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_307` x1 |
| key_308 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_308` x1 |
| key_309 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_309` x1 |
| key_310 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_310` x1 |
| key_311 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_311` x1 |
| key_312 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_312` x1 |
| key_313 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_313` x1 |
| key_314 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_314` x1 |
| key_315 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_315` x1 |
| key_316 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_316` x1 |
| key_317 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_317` x1 |
| key_318 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_318` x1 |
| key_319 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_319` x1 |
| key_320 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_320` x1 |
| key_321 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_321` x1 |
| key_322 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_322` x1 |
| key_323 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_323` x1 |
| key_324 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_324` x1 |
| key_325 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_325` x1 |
| key_326 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_326` x1 |
| key_327 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_327` x1 |
| key_328 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_328` x1 |
| key_329 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_329` x1 |
| key_330 | 1 | yes | `$.key_70.key_53.key_54.key_304.key_330` x1 |
| key_331 | 1 | yes | `$.key_70.key_53.key_54.key_60.key_331` x1 |
| key_332 | 1 | yes | `$.key_70.key_53.key_54.key_60.key_332` x1 |
| key_333 | 1 | no | `$.key_70.key_61.key_333` x1 |
| key_334 | 157 | no | `$.key_70.key_61.key_333[][].key_334` x157 |
| key_335 | 1 | no | `$.key_70.key_61.key_333[][].key_335` x1 |
| key_336 | 1 | no | `$.key_70.key_61.key_336` x1 |
| key_337 | 1 | no | `$.key_337` x1 |
| key_338 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338` x1 |
| key_339 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338[].key_339` x1 |
| key_340 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338[].key_339.key_340` x1 |
| key_341 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338[].key_339.key_341` x1 |
| key_342 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_338[].key_339.key_342` x1 |
| key_343 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_343` x1 |
| key_344 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_344` x1 |
| key_345 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_345` x1 |
| key_346 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_346` x1 |
| key_347 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_347` x1 |
| key_348 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_348` x1 |
| key_349 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349` x1 |
| key_350 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349[].key_350` x1 |
| key_351 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349[].key_351` x1 |
| key_352 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349[].key_352` x1 |
| key_353 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_349[].key_353` x1 |
| key_354 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_354` x1 |
| key_355 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_355` x1 |
| key_356 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_356` x1 |
| key_357 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_357` x1 |
| key_358 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_358` x1 |
| key_359 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_359` x1 |
| key_360 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_360` x1 |
| key_361 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_361` x1 |
| key_362 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_362` x1 |
| key_363 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_363` x1 |
| key_364 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_364` x1 |
| key_365 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_365` x1 |
| key_366 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_366` x1 |
| key_367 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_367` x1 |
| key_368 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].user.key_368` x1 |
| key_369 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].user.key_369` x1 |
| key_370 | 2 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].user.key_370` x1, `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_370` x1 |
| key_371 | 2 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].user.key_370.key_371` x1, `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_370.key_371` x1 |
| key_372 | 22 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].user.key_372` x1, `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_372` x1, `$.data.key_414.key_415[].key_372` x20 |
| key_373 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_373` x1 |
| key_374 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_374` x1 |
| key_375 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_375` x1 |
| key_376 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_376` x1 |
| key_377 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_377` x1 |
| key_378 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_378` x1 |
| key_379 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_379` x1 |
| key_380 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_380` x1 |
| key_381 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_381` x1 |
| key_382 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_382` x1 |
| key_383 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_383` x1 |
| key_384 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_384` x1 |
| key_385 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_385` x1 |
| key_386 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_385.key_386` x1 |
| key_387 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].items[].key_385.key_387` x1 |
| key_388 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_370.key_388` x1 |
| key_389 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_370.key_389` x1 |
| key_390 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_370.key_390` x1 |
| key_391 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_391` x1 |
| key_392 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_392` x1 |
| key_393 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].user.key_393` x1 |
| key_394 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].key_394` x1 |
| key_395 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.reels_media[].key_395` x1 |
| key_396 | 1 | no | `$.data.xdt_api__v1__feed__reels_media.key_396` x1 |
| key_397 | 1 | no | `$.data.xdt_viewer.user.key_397` x1 |
| key_398 | 4 | no | `$.extensions.key_398` x4 |
| key_399 | 4 | yes | `$.extensions.key_398.key_399` x4 |
| key_400 | 4 | yes | `$.extensions.key_398.key_400` x4 |
| key_401 | 4 | no | `$.extensions.key_401` x4 |
| key_402 | 1 | no | `$.data.key_402` x1 |
| key_403 | 1 | no | `$.data.key_402.key_403` x1 |
| key_404 | 1 | no | `$.data.key_402.key_404` x1 |
| key_405 | 1 | no | `$.extensions.key_405` x1 |
| key_406 | 1 | no | `$.extensions.key_405.key_406` x1 |
| key_407 | 1 | no | `$.key_1.key_407` x1 |
| key_408 | 1 | no | `$.key_1.key_407.key_408` x1 |
| key_409 | 1 | no | `$.key_1.key_52.key_53.key_54.key_57.key_409` x1 |
| key_410 | 1 | no | `$.data.key_410` x1 |
| key_411 | 1 | no | `$.key_411` x1 |
| key_412 | 1 | no | `$.key_412` x1 |
| key_413 | 1 | no | `$.key_413` x1 |
| key_414 | 1 | no | `$.data.key_414` x1 |
| key_415 | 1 | no | `$.data.key_414.key_415` x1 |
| key_416 | 20 | no | `$.data.key_414.key_415[].key_416` x20 |
| key_417 | 20 | no | `$.data.key_414.key_415[].key_417` x20 |
| key_418 | 20 | no | `$.data.key_414.key_415[].key_418` x20 |

## Replacement counts

- object keys replaced with key_N: 1298 (418 distinct)
- keep-list entries used: 3 of 7
- dash: 1
- media: 26
- str: 1259
- url: 63
- user: 22

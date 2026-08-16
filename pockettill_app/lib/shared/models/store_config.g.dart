// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_config.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoreConfigCollection on Isar {
  IsarCollection<StoreConfig> get storeConfigs => this.collection();
}

const StoreConfigSchema = CollectionSchema(
  name: r'StoreConfig',
  id: 2883021225625652483,
  properties: {
    r'address': PropertySchema(
      id: 0,
      name: r'address',
      type: IsarType.string,
    ),
    r'authPhone': PropertySchema(
      id: 1,
      name: r'authPhone',
      type: IsarType.string,
    ),
    r'authUserId': PropertySchema(
      id: 2,
      name: r'authUserId',
      type: IsarType.string,
    ),
    r'deviceId': PropertySchema(
      id: 3,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'isBetaAdopter': PropertySchema(
      id: 4,
      name: r'isBetaAdopter',
      type: IsarType.bool,
    ),
    r'isLoggedIn': PropertySchema(
      id: 5,
      name: r'isLoggedIn',
      type: IsarType.bool,
    ),
    r'lastSyncedAt': PropertySchema(
      id: 6,
      name: r'lastSyncedAt',
      type: IsarType.dateTime,
    ),
    r'ownerName': PropertySchema(
      id: 7,
      name: r'ownerName',
      type: IsarType.string,
    ),
    r'ownerPhone': PropertySchema(
      id: 8,
      name: r'ownerPhone',
      type: IsarType.string,
    ),
    r'paymentSoundEnabled': PropertySchema(
      id: 9,
      name: r'paymentSoundEnabled',
      type: IsarType.bool,
    ),
    r'scanSoundEnabled': PropertySchema(
      id: 10,
      name: r'scanSoundEnabled',
      type: IsarType.bool,
    ),
    r'storeId': PropertySchema(
      id: 11,
      name: r'storeId',
      type: IsarType.string,
    ),
    r'storeName': PropertySchema(
      id: 12,
      name: r'storeName',
      type: IsarType.string,
    )
  },
  estimateSize: _storeConfigEstimateSize,
  serialize: _storeConfigSerialize,
  deserialize: _storeConfigDeserialize,
  deserializeProp: _storeConfigDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _storeConfigGetId,
  getLinks: _storeConfigGetLinks,
  attach: _storeConfigAttach,
  version: '3.1.0+1',
);

int _storeConfigEstimateSize(
  StoreConfig object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.address;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.authPhone;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.authUserId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.deviceId.length * 3;
  {
    final value = object.ownerName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ownerPhone;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.storeId.length * 3;
  bytesCount += 3 + object.storeName.length * 3;
  return bytesCount;
}

void _storeConfigSerialize(
  StoreConfig object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.address);
  writer.writeString(offsets[1], object.authPhone);
  writer.writeString(offsets[2], object.authUserId);
  writer.writeString(offsets[3], object.deviceId);
  writer.writeBool(offsets[4], object.isBetaAdopter);
  writer.writeBool(offsets[5], object.isLoggedIn);
  writer.writeDateTime(offsets[6], object.lastSyncedAt);
  writer.writeString(offsets[7], object.ownerName);
  writer.writeString(offsets[8], object.ownerPhone);
  writer.writeBool(offsets[9], object.paymentSoundEnabled);
  writer.writeBool(offsets[10], object.scanSoundEnabled);
  writer.writeString(offsets[11], object.storeId);
  writer.writeString(offsets[12], object.storeName);
}

StoreConfig _storeConfigDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoreConfig();
  object.address = reader.readStringOrNull(offsets[0]);
  object.authPhone = reader.readStringOrNull(offsets[1]);
  object.authUserId = reader.readStringOrNull(offsets[2]);
  object.deviceId = reader.readString(offsets[3]);
  object.id = id;
  object.isBetaAdopter = reader.readBool(offsets[4]);
  object.isLoggedIn = reader.readBool(offsets[5]);
  object.lastSyncedAt = reader.readDateTimeOrNull(offsets[6]);
  object.ownerName = reader.readStringOrNull(offsets[7]);
  object.ownerPhone = reader.readStringOrNull(offsets[8]);
  object.paymentSoundEnabled = reader.readBool(offsets[9]);
  object.scanSoundEnabled = reader.readBool(offsets[10]);
  object.storeId = reader.readString(offsets[11]);
  object.storeName = reader.readString(offsets[12]);
  return object;
}

P _storeConfigDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readBool(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storeConfigGetId(StoreConfig object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storeConfigGetLinks(StoreConfig object) {
  return [];
}

void _storeConfigAttach(
    IsarCollection<dynamic> col, Id id, StoreConfig object) {
  object.id = id;
}

extension StoreConfigQueryWhereSort
    on QueryBuilder<StoreConfig, StoreConfig, QWhere> {
  QueryBuilder<StoreConfig, StoreConfig, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoreConfigQueryWhere
    on QueryBuilder<StoreConfig, StoreConfig, QWhereClause> {
  QueryBuilder<StoreConfig, StoreConfig, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StoreConfigQueryFilter
    on QueryBuilder<StoreConfig, StoreConfig, QFilterCondition> {
  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'address',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'address',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'address',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'address',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> addressMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'address',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'address',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      addressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'address',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authPhone',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authPhone',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authPhone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authPhone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authPhoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'authUserId',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'authUserId',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'authUserId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'authUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'authUserId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'authUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      authUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'authUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> deviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> deviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> deviceIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      isBetaAdopterEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBetaAdopter',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      isLoggedInEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isLoggedIn',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSyncedAt',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSyncedAt',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSyncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSyncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSyncedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      lastSyncedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSyncedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ownerName',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ownerName',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerName',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerName',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ownerPhone',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ownerPhone',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerPhone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerPhone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      ownerPhoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      paymentSoundEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paymentSoundEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      scanSoundEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scanSoundEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition> storeIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storeId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'storeName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'storeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'storeName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'storeName',
        value: '',
      ));
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterFilterCondition>
      storeNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'storeName',
        value: '',
      ));
    });
  }
}

extension StoreConfigQueryObject
    on QueryBuilder<StoreConfig, StoreConfig, QFilterCondition> {}

extension StoreConfigQueryLinks
    on QueryBuilder<StoreConfig, StoreConfig, QFilterCondition> {}

extension StoreConfigQuerySortBy
    on QueryBuilder<StoreConfig, StoreConfig, QSortBy> {
  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAuthPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authPhone', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAuthPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authPhone', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAuthUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authUserId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByAuthUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authUserId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByIsBetaAdopter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBetaAdopter', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByIsBetaAdopterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBetaAdopter', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByIsLoggedIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLoggedIn', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByIsLoggedInDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLoggedIn', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByOwnerName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerName', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByOwnerNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerName', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByOwnerPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerPhone', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByOwnerPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerPhone', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByPaymentSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentSoundEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByPaymentSoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentSoundEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByScanSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanSoundEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      sortByScanSoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanSoundEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByStoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByStoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByStoreName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeName', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> sortByStoreNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeName', Sort.desc);
    });
  }
}

extension StoreConfigQuerySortThenBy
    on QueryBuilder<StoreConfig, StoreConfig, QSortThenBy> {
  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAuthPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authPhone', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAuthPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authPhone', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAuthUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authUserId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByAuthUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'authUserId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByIsBetaAdopter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBetaAdopter', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByIsBetaAdopterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBetaAdopter', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByIsLoggedIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLoggedIn', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByIsLoggedInDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isLoggedIn', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByOwnerName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerName', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByOwnerNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerName', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByOwnerPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerPhone', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByOwnerPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerPhone', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByPaymentSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentSoundEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByPaymentSoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentSoundEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByScanSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanSoundEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy>
      thenByScanSoundEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scanSoundEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByStoreId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByStoreIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeId', Sort.desc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByStoreName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeName', Sort.asc);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QAfterSortBy> thenByStoreNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'storeName', Sort.desc);
    });
  }
}

extension StoreConfigQueryWhereDistinct
    on QueryBuilder<StoreConfig, StoreConfig, QDistinct> {
  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByAddress(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'address', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByAuthPhone(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authPhone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByAuthUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'authUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByIsBetaAdopter() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isBetaAdopter');
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByIsLoggedIn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isLoggedIn');
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncedAt');
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByOwnerName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByOwnerPhone(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerPhone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct>
      distinctByPaymentSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paymentSoundEnabled');
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct>
      distinctByScanSoundEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scanSoundEnabled');
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByStoreId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoreConfig, StoreConfig, QDistinct> distinctByStoreName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'storeName', caseSensitive: caseSensitive);
    });
  }
}

extension StoreConfigQueryProperty
    on QueryBuilder<StoreConfig, StoreConfig, QQueryProperty> {
  QueryBuilder<StoreConfig, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoreConfig, String?, QQueryOperations> addressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'address');
    });
  }

  QueryBuilder<StoreConfig, String?, QQueryOperations> authPhoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authPhone');
    });
  }

  QueryBuilder<StoreConfig, String?, QQueryOperations> authUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'authUserId');
    });
  }

  QueryBuilder<StoreConfig, String, QQueryOperations> deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<StoreConfig, bool, QQueryOperations> isBetaAdopterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isBetaAdopter');
    });
  }

  QueryBuilder<StoreConfig, bool, QQueryOperations> isLoggedInProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isLoggedIn');
    });
  }

  QueryBuilder<StoreConfig, DateTime?, QQueryOperations>
      lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncedAt');
    });
  }

  QueryBuilder<StoreConfig, String?, QQueryOperations> ownerNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerName');
    });
  }

  QueryBuilder<StoreConfig, String?, QQueryOperations> ownerPhoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerPhone');
    });
  }

  QueryBuilder<StoreConfig, bool, QQueryOperations>
      paymentSoundEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentSoundEnabled');
    });
  }

  QueryBuilder<StoreConfig, bool, QQueryOperations> scanSoundEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scanSoundEnabled');
    });
  }

  QueryBuilder<StoreConfig, String, QQueryOperations> storeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storeId');
    });
  }

  QueryBuilder<StoreConfig, String, QQueryOperations> storeNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'storeName');
    });
  }
}

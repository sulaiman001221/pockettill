// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReturnRecordCollection on Isar {
  IsarCollection<ReturnRecord> get returnRecords => this.collection();
}

const ReturnRecordSchema = CollectionSchema(
  name: r'ReturnRecord',
  id: -8100134467443344680,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'customerId': PropertySchema(
      id: 1,
      name: r'customerId',
      type: IsarType.string,
    ),
    r'customerOwes': PropertySchema(
      id: 2,
      name: r'customerOwes',
      type: IsarType.double,
    ),
    r'customerReceives': PropertySchema(
      id: 3,
      name: r'customerReceives',
      type: IsarType.double,
    ),
    r'deviceId': PropertySchema(
      id: 4,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'exchangeProductName': PropertySchema(
      id: 5,
      name: r'exchangeProductName',
      type: IsarType.string,
    ),
    r'exchangeProductUuid': PropertySchema(
      id: 6,
      name: r'exchangeProductUuid',
      type: IsarType.string,
    ),
    r'itemsValue': PropertySchema(
      id: 7,
      name: r'itemsValue',
      type: IsarType.double,
    ),
    r'reason': PropertySchema(
      id: 8,
      name: r'reason',
      type: IsarType.string,
    ),
    r'resolutionType': PropertySchema(
      id: 9,
      name: r'resolutionType',
      type: IsarType.string,
    ),
    r'saleUuid': PropertySchema(
      id: 10,
      name: r'saleUuid',
      type: IsarType.string,
    ),
    r'stockAction': PropertySchema(
      id: 11,
      name: r'stockAction',
      type: IsarType.string,
    ),
    r'synced': PropertySchema(
      id: 12,
      name: r'synced',
      type: IsarType.bool,
    ),
    r'uuid': PropertySchema(
      id: 13,
      name: r'uuid',
      type: IsarType.string,
    )
  },
  estimateSize: _returnRecordEstimateSize,
  serialize: _returnRecordSerialize,
  deserialize: _returnRecordDeserialize,
  deserializeProp: _returnRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _returnRecordGetId,
  getLinks: _returnRecordGetLinks,
  attach: _returnRecordAttach,
  version: '3.1.0+1',
);

int _returnRecordEstimateSize(
  ReturnRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.customerId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.deviceId.length * 3;
  {
    final value = object.exchangeProductName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.exchangeProductUuid;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.reason.length * 3;
  bytesCount += 3 + object.resolutionType.length * 3;
  bytesCount += 3 + object.saleUuid.length * 3;
  bytesCount += 3 + object.stockAction.length * 3;
  bytesCount += 3 + object.uuid.length * 3;
  return bytesCount;
}

void _returnRecordSerialize(
  ReturnRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.customerId);
  writer.writeDouble(offsets[2], object.customerOwes);
  writer.writeDouble(offsets[3], object.customerReceives);
  writer.writeString(offsets[4], object.deviceId);
  writer.writeString(offsets[5], object.exchangeProductName);
  writer.writeString(offsets[6], object.exchangeProductUuid);
  writer.writeDouble(offsets[7], object.itemsValue);
  writer.writeString(offsets[8], object.reason);
  writer.writeString(offsets[9], object.resolutionType);
  writer.writeString(offsets[10], object.saleUuid);
  writer.writeString(offsets[11], object.stockAction);
  writer.writeBool(offsets[12], object.synced);
  writer.writeString(offsets[13], object.uuid);
}

ReturnRecord _returnRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReturnRecord();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.customerId = reader.readStringOrNull(offsets[1]);
  object.customerOwes = reader.readDouble(offsets[2]);
  object.customerReceives = reader.readDouble(offsets[3]);
  object.deviceId = reader.readString(offsets[4]);
  object.exchangeProductName = reader.readStringOrNull(offsets[5]);
  object.exchangeProductUuid = reader.readStringOrNull(offsets[6]);
  object.id = id;
  object.itemsValue = reader.readDouble(offsets[7]);
  object.reason = reader.readString(offsets[8]);
  object.resolutionType = reader.readString(offsets[9]);
  object.saleUuid = reader.readString(offsets[10]);
  object.stockAction = reader.readString(offsets[11]);
  object.synced = reader.readBool(offsets[12]);
  object.uuid = reader.readString(offsets[13]);
  return object;
}

P _returnRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readBool(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _returnRecordGetId(ReturnRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _returnRecordGetLinks(ReturnRecord object) {
  return [];
}

void _returnRecordAttach(
    IsarCollection<dynamic> col, Id id, ReturnRecord object) {
  object.id = id;
}

extension ReturnRecordQueryWhereSort
    on QueryBuilder<ReturnRecord, ReturnRecord, QWhere> {
  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReturnRecordQueryWhere
    on QueryBuilder<ReturnRecord, ReturnRecord, QWhereClause> {
  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterWhereClause> idBetween(
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

extension ReturnRecordQueryFilter
    on QueryBuilder<ReturnRecord, ReturnRecord, QFilterCondition> {
  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'customerId',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'customerId',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customerId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customerId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customerId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customerId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customerId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerOwesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customerOwes',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerOwesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customerOwes',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerOwesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customerOwes',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerOwesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customerOwes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerReceivesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customerReceives',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerReceivesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customerReceives',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerReceivesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customerReceives',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      customerReceivesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customerReceives',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdEqualTo(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdBetween(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'exchangeProductName',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'exchangeProductName',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'exchangeProductName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'exchangeProductName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'exchangeProductName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exchangeProductName',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'exchangeProductName',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'exchangeProductUuid',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'exchangeProductUuid',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'exchangeProductUuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'exchangeProductUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'exchangeProductUuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exchangeProductUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      exchangeProductUuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'exchangeProductUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      itemsValueEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemsValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      itemsValueGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemsValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      itemsValueLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemsValue',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      itemsValueBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemsValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> reasonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> reasonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reason',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reason',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> reasonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reason',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      reasonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reason',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolutionType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolutionType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolutionType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolutionType',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      resolutionTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolutionType',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'saleUuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'saleUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'saleUuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'saleUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      saleUuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'saleUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stockAction',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'stockAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'stockAction',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stockAction',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      stockActionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'stockAction',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> syncedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'synced',
        value: value,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      uuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      uuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition> uuidMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      uuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uuid',
        value: '',
      ));
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterFilterCondition>
      uuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uuid',
        value: '',
      ));
    });
  }
}

extension ReturnRecordQueryObject
    on QueryBuilder<ReturnRecord, ReturnRecord, QFilterCondition> {}

extension ReturnRecordQueryLinks
    on QueryBuilder<ReturnRecord, ReturnRecord, QFilterCondition> {}

extension ReturnRecordQuerySortBy
    on QueryBuilder<ReturnRecord, ReturnRecord, QSortBy> {
  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByCustomerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByCustomerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByCustomerOwes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerOwes', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByCustomerOwesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerOwes', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByCustomerReceives() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerReceives', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByCustomerReceivesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerReceives', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByExchangeProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductName', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByExchangeProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductName', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByExchangeProductUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductUuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByExchangeProductUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductUuid', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByItemsValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsValue', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByItemsValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsValue', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByResolutionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionType', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByResolutionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionType', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortBySaleUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saleUuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortBySaleUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saleUuid', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByStockAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAction', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      sortByStockActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAction', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortBySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortBySyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> sortByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension ReturnRecordQuerySortThenBy
    on QueryBuilder<ReturnRecord, ReturnRecord, QSortThenBy> {
  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByCustomerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByCustomerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerId', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByCustomerOwes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerOwes', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByCustomerOwesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerOwes', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByCustomerReceives() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerReceives', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByCustomerReceivesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customerReceives', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByExchangeProductName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductName', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByExchangeProductNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductName', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByExchangeProductUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductUuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByExchangeProductUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exchangeProductUuid', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByItemsValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsValue', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByItemsValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemsValue', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByReason() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByReasonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reason', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByResolutionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionType', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByResolutionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolutionType', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenBySaleUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saleUuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenBySaleUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saleUuid', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByStockAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAction', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy>
      thenByStockActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stockAction', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenBySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenBySyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synced', Sort.desc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.asc);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QAfterSortBy> thenByUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uuid', Sort.desc);
    });
  }
}

extension ReturnRecordQueryWhereDistinct
    on QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> {
  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByCustomerId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customerId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByCustomerOwes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customerOwes');
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct>
      distinctByCustomerReceives() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customerReceives');
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct>
      distinctByExchangeProductName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'exchangeProductName',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct>
      distinctByExchangeProductUuid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'exchangeProductUuid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByItemsValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemsValue');
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByReason(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reason', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByResolutionType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolutionType',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctBySaleUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'saleUuid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByStockAction(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stockAction', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctBySynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synced');
    });
  }

  QueryBuilder<ReturnRecord, ReturnRecord, QDistinct> distinctByUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uuid', caseSensitive: caseSensitive);
    });
  }
}

extension ReturnRecordQueryProperty
    on QueryBuilder<ReturnRecord, ReturnRecord, QQueryProperty> {
  QueryBuilder<ReturnRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReturnRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ReturnRecord, String?, QQueryOperations> customerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerId');
    });
  }

  QueryBuilder<ReturnRecord, double, QQueryOperations> customerOwesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerOwes');
    });
  }

  QueryBuilder<ReturnRecord, double, QQueryOperations>
      customerReceivesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customerReceives');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations> deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<ReturnRecord, String?, QQueryOperations>
      exchangeProductNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'exchangeProductName');
    });
  }

  QueryBuilder<ReturnRecord, String?, QQueryOperations>
      exchangeProductUuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'exchangeProductUuid');
    });
  }

  QueryBuilder<ReturnRecord, double, QQueryOperations> itemsValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemsValue');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations> reasonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reason');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations>
      resolutionTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolutionType');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations> saleUuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'saleUuid');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations> stockActionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stockAction');
    });
  }

  QueryBuilder<ReturnRecord, bool, QQueryOperations> syncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synced');
    });
  }

  QueryBuilder<ReturnRecord, String, QQueryOperations> uuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uuid');
    });
  }
}

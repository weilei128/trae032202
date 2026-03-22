package com.accounting.repository;

import com.accounting.entity.Record;
import com.accounting.util.CsvUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import javax.annotation.PostConstruct;
import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

@Repository
public class RecordRepository {

    @Value("${app.data.path}")
    private String dataPath;

    private String filePath;
    private static final String[] HEADERS = {"id", "userId", "amount", "type", "category", "remark", "createTime", "updateTime"};
    private final AtomicLong idGenerator = new AtomicLong(1);

    @PostConstruct
    public void init() throws IOException {
        this.filePath = dataPath + "/records.csv";
        CsvUtil.ensureFileExists(filePath, HEADERS);
        loadMaxId();
    }

    private void loadMaxId() throws IOException {
        List<Record> records = findAll();
        records.stream().mapToLong(Record::getId).max()
                .ifPresent(maxId -> idGenerator.set(maxId + 1));
    }

    public List<Record> findAll() {
        try {
            return CsvUtil.readAndConvert(filePath, this::mapToRecord);
        } catch (IOException e) {
            throw new RuntimeException("读取记录数据失败", e);
        }
    }

    public List<Record> findByUserId(Long userId) {
        return findAll().stream().filter(r -> r.getUserId().equals(userId)).collect(Collectors.toList());
    }

    public Optional<Record> findById(Long id) {
        return findAll().stream().filter(r -> r.getId().equals(id)).findFirst();
    }

    public Record save(Record record) {
        try {
            if (record.getId() == null) {
                record.setId(idGenerator.getAndIncrement());
                record.setCreateTime(LocalDateTime.now());
            }
            record.setUpdateTime(LocalDateTime.now());
            
            List<Record> records = findAll();
            records.removeIf(r -> r.getId().equals(record.getId()));
            records.add(record);
            CsvUtil.writeAll(filePath, records.stream().map(this::mapToArray).collect(Collectors.toList()));
            return record;
        } catch (IOException e) {
            throw new RuntimeException("保存记录数据失败", e);
        }
    }

    public void deleteById(Long id) {
        try {
            List<Record> records = findAll();
            records.removeIf(r -> r.getId().equals(id));
            CsvUtil.writeAll(filePath, records.stream().map(this::mapToArray).collect(Collectors.toList()));
        } catch (IOException e) {
            throw new RuntimeException("删除记录数据失败", e);
        }
    }

    private Record mapToRecord(String[] row) {
        if (row == null || row.length < 8) return null;
        Record record = new Record();
        record.setId(Long.parseLong(row[0]));
        record.setUserId(Long.parseLong(row[1]));
        record.setAmount(new BigDecimal(row[2]));
        record.setType(row[3]);
        record.setCategory(row[4]);
        record.setRemark(row[5]);
        record.setCreateTime(LocalDateTime.parse(row[6]));
        record.setUpdateTime(LocalDateTime.parse(row[7]));
        return record;
    }

    private String[] mapToArray(Record record) {
        return new String[]{
                record.getId().toString(),
                record.getUserId().toString(),
                record.getAmount().toString(),
                record.getType(),
                record.getCategory(),
                record.getRemark() != null ? record.getRemark() : "",
                record.getCreateTime().toString(),
                record.getUpdateTime().toString()
        };
    }
}

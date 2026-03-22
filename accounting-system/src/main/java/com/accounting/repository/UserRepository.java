package com.accounting.repository;

import com.accounting.entity.User;
import com.accounting.util.CsvUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import javax.annotation.PostConstruct;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

@Repository
public class UserRepository {

    @Value("${app.data.path}")
    private String dataPath;

    private String filePath;
    private static final String[] HEADERS = {"id", "account", "password", "nickname", "createTime", "updateTime"};
    private final AtomicLong idGenerator = new AtomicLong(1);

    @PostConstruct
    public void init() throws IOException {
        this.filePath = dataPath + "/users.csv";
        CsvUtil.ensureFileExists(filePath, HEADERS);
        loadMaxId();
    }

    private void loadMaxId() throws IOException {
        List<User> users = findAll();
        users.stream().mapToLong(User::getId).max()
                .ifPresent(maxId -> idGenerator.set(maxId + 1));
    }

    public List<User> findAll() {
        try {
            return CsvUtil.readAndConvert(filePath, this::mapToUser);
        } catch (IOException e) {
            throw new RuntimeException("读取用户数据失败", e);
        }
    }

    public Optional<User> findById(Long id) {
        return findAll().stream().filter(u -> u.getId().equals(id)).findFirst();
    }

    public Optional<User> findByAccount(String account) {
        return findAll().stream().filter(u -> u.getAccount().equals(account)).findFirst();
    }

    public User save(User user) {
        try {
            if (user.getId() == null) {
                user.setId(idGenerator.getAndIncrement());
                user.setCreateTime(LocalDateTime.now());
            }
            user.setUpdateTime(LocalDateTime.now());
            
                List<User> users = findAll();
                users.removeIf(u -> u.getId().equals(user.getId()));
                users.add(user);
                CsvUtil.writeAll(filePath, users.stream().map(this::mapToArray).collect(Collectors.toList()));
            return user;
        } catch (IOException e) {
            throw new RuntimeException("保存用户数据失败", e);
        }
    }

    private User mapToUser(String[] row) {
        if (row == null || row.length < 6) return null;
        User user = new User();
        user.setId(Long.parseLong(row[0]));
        user.setAccount(row[1]);
        user.setPassword(row[2]);
        user.setNickname(row[3]);
        user.setCreateTime(LocalDateTime.parse(row[4]));
        user.setUpdateTime(LocalDateTime.parse(row[5]));
        return user;
    }

    private String[] mapToArray(User user) {
        return new String[]{
                user.getId().toString(),
                user.getAccount(),
                user.getPassword(),
                user.getNickname() != null ? user.getNickname() : "",
                user.getCreateTime().toString(),
                user.getUpdateTime().toString()
        };
    }
}

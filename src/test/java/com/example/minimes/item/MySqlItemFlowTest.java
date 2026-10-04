package com.example.minimes.item;

import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.test.context.ActiveProfiles;

// 같은 화면·업무 검증을 실제 MySQL에서도 실행한다. 전용 검증 DB만 사용한다.
@EnabledIfEnvironmentVariable(named = "RUN_MYSQL_TESTS", matches = "true")
@ActiveProfiles(profiles = "mysql-test", inheritProfiles = false)
public class MySqlItemFlowTest extends ItemFlowTest {
}

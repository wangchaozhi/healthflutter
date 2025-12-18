package database

import (
	"database/sql"
	"log"

	_ "modernc.org/sqlite"
)

// InitDB 初始化数据库连接
func InitDB(dbPath string) error {
	var err error
	DB, err = sql.Open("sqlite", dbPath)
	if err != nil {
		return err
	}

	// 创建用户表
	createUserTableSQL := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	_, err = DB.Exec(createUserTableSQL)
	if err != nil {
		return err
	}

	// 创建健康活动记录表
	createActivityTableSQL := `
	CREATE TABLE IF NOT EXISTS health_activities (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		record_date TEXT NOT NULL,
		record_time TEXT NOT NULL,
		week_day TEXT NOT NULL,
		duration INTEGER NOT NULL,
		remark TEXT,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (user_id) REFERENCES users(id)
	);`

	_, err = DB.Exec(createActivityTableSQL)
	if err != nil {
		return err
	}

         // 初始化抖音文件表
        if err := InitDouyinTable(); err != nil {
            return err
        }

        // 初始化文件传输表
        if err := InitFileTransferTable(); err != nil {
            return err
        }

        log.Println("数据库初始化成功")
        return nil
}

// CloseDB 关闭数据库连接
func CloseDB() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}


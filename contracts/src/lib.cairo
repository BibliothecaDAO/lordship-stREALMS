mod lordship;
mod components {
    mod strealm;
    mod erc721 {
        mod extensions;
    }
}

mod tests {
    mod components {
        #[cfg(test)]
        mod test_strealm;
    }
    mod mocks {
        mod strealm_mock;
    }
}

registerSettingsPage(({ settings }) => (
  <Page>
    <Section
      title={
        <Text bold align="center">
          Collega Momentum
        </Text>
      }
    >
      <Text>
        Genera un codice in Momentum: Profilo, Dispositivi e smartwatch,
        Fitbit OS. Il codice scade dopo 10 minuti e non contiene dati personali.
      </Text>
      <TextInput
        label="Codice di associazione"
        settingsKey="pairingCode"
        placeholder="ABCD-EFGH"
      />
      <Text>
        Lo scoring viene sempre salvato prima sul watch. La sincronizzazione
        riparte automaticamente quando il telefono torna raggiungibile.
      </Text>
    </Section>
  </Page>
));
